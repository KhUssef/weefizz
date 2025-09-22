import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { CreateGabaritDto } from './dto/create-gabarit.dto';
import { UpdateGabaritDto } from './dto/update-gabarit.dto';
import { Gabarit } from './entities/gabarit.entity';
import { BaseService } from '../common/generic.service'; 
import { SafeUserDto } from '../user/dto/safe-user.dto';
import * as sharp from 'sharp';
import * as path from 'path';
import * as fs from 'fs'; 
import axios from 'axios';
import * as FormData from 'form-data';
import { Piece } from '../piece/entities/piece.entity';
import { Fabric } from '../fabric/entities/fabric.entity';

@Injectable()
export class GabaritService {
  private getBaseUrl(): string {
    let url = process.env.GABARIT_URL || '127.0.0.1:8000';
    if (!/^https?:\/\//i.test(url)) {
      url = 'http://' + url;
    }
    return url.replace(/\/$/, '');
  }
  constructor(
    @InjectRepository(Gabarit)
    private readonly gabaritRepository: Repository<Gabarit>,
  @InjectRepository(Piece)
  private readonly pieceRepository: Repository<Piece>,
  @InjectRepository(Fabric)
  private readonly fabricRepository: Repository<Fabric>,
  ) {}

  async create(createGabaritDto: CreateGabaritDto & { filePath: string }, userId: number): Promise<Gabarit> {
    // Get file extension and base name from the already unique file path
    const fileExtension = path.extname(createGabaritDto.filePath);
    const baseName = path.basename(createGabaritDto.filePath, fileExtension);
    
  // Create icon path by adding '-icon' suffix to the existing unique filename
    const iconFileName = `${baseName}-icon${fileExtension}`;
    const iconFilePath = `uploads/gabarits/${iconFileName}`;
    
    // Full paths for file operations
  const fullOriginalPath = path.join(process.cwd(), createGabaritDto.filePath);
    const fullIconPath = path.join(process.cwd(), iconFilePath);
    
    try {
      // Ensure the uploads/gabarits directory exists
      const uploadsDir = path.join(process.cwd(), 'uploads/gabarits');
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }
      
      // Create downscaled icon version using sharp from the original file
      await sharp(fullOriginalPath)
        .resize(200, 200, { // Resize to 200x200 pixels
          fit: 'cover', // Maintain aspect ratio and crop if necessary
          position: 'center'
        })
        .jpeg({ quality: 80 }) // Convert to JPEG with 80% quality
        .toFile(fullIconPath);
      
      // Create the gabarit entity with both file paths
      const gabarit = this.gabaritRepository.create({
        name: (createGabaritDto as any).name,
        description: (createGabaritDto as any).description,
        scale: (createGabaritDto as any).scale,
        originalImage: createGabaritDto.filePath,
        processedImage: null as any,
        iconPath: iconFilePath,
        user: { id: userId } as any,
      });
      
      return this.gabaritRepository.save(gabarit);
      
    } catch (error) {
      // Clean up icon file if there's an error (keep original file)
      if (fs.existsSync(fullIconPath)) {
        fs.unlinkSync(fullIconPath);
      }
      throw error;
    }
  }

  // Compute polygon area using the shoelace formula; expects [[x,y], ...]
  private computePolygonArea(points: Array<[number, number]>): number {
    if (!Array.isArray(points) || points.length < 3) return 0;
    let sum = 0;
    for (let i = 0; i < points.length; i++) {
      const [x1, y1] = points[i];
      const [x2, y2] = points[(i + 1) % points.length];
      sum += x1 * y2 - x2 * y1;
    }
    return Math.abs(sum / 2);
  }
  
  // Custom update method to handle file replacement
  //NEVER USRED BASICALLY
  async updateWithFile(id: string, userId: number, updateData: Partial<Gabarit>, newFilePath?: string): Promise<Gabarit> {
    const existingGabarit = await this.gabaritRepository.findOne({
      where: { id: id, user: { id: userId } },
    });
    if (!existingGabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }
    
    // If new file is provided, regenerate ONLY the icon using it; do not change original/processed images
    if (newFilePath) {
      const fileExtension = path.extname(newFilePath);
      const baseName = path.basename(newFilePath, fileExtension);
      const iconFileName = `${baseName}-icon${fileExtension}`;
      const iconFilePath = `uploads/gabarits/${iconFileName}`;

      const fullNewPath = path.join(process.cwd(), newFilePath);
      const fullIconPath = path.join(process.cwd(), iconFilePath);

      try {
        // Ensure target directory exists
        const uploadsDir = path.join(process.cwd(), 'uploads', 'gabarits');
        if (!fs.existsSync(uploadsDir)) {
          fs.mkdirSync(uploadsDir, { recursive: true });
        }

        // Generate icon from the uploaded file
        await sharp(fullNewPath)
          .resize(200, 200, { fit: 'cover', position: 'center' })
          .jpeg({ quality: 80 })
          .toFile(fullIconPath);

        // Remove previous icon file if it exists
        if (existingGabarit.iconPath) {
          const oldIconPath = path.join(process.cwd(), existingGabarit.iconPath);
          if (fs.existsSync(oldIconPath)) {
            try { fs.unlinkSync(oldIconPath); } catch {}
          }
        }

        // Update only the iconPath
        updateData.iconPath = iconFilePath;

        // Optional: cleanup the uploaded temp/original if we only needed it for icon
        if (fs.existsSync(fullNewPath)) {
          try { fs.unlinkSync(fullNewPath); } catch {}
        }
      } catch (error) {
        if (fs.existsSync(fullIconPath)) {
          try { fs.unlinkSync(fullIconPath); } catch {}
        }
        throw error;
      }
    }
    
    this.gabaritRepository.merge(existingGabarit, updateData);
    return this.gabaritRepository.save(existingGabarit);
  }

  // Calculate total required amount per fabric for a given gabarit
  async calculateFabricRequirements(
    gabaritId: string,
    userId: number,
    quantity: number,
  ): Promise<Record<string, number>> {
    // Load gabarit with pieces and their fabrics, ensure ownership
    const gabarit = await this.gabaritRepository.findOne({
      where: { id: gabaritId, user: { id: userId } },
      relations: ['pieces', 'pieces.fabric'],
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${gabaritId} not found or you don't have access to it`);
    }

    const scale = gabarit.scale || 1;
    const totals: Record<string, number> = {};

    for (const piece of gabarit.pieces || []) {
      const fabricId = (piece as any)?.fabric?.id as string | undefined;
      if (!fabricId) continue; // skip pieces without an assigned fabric

      const area = piece.area * piece.NumberOfPieces || 0; // stored in pixels^2
      const amount = area * scale * quantity; // simple scaling as requested

      if (!totals[fabricId]) totals[fabricId] = 0;
      totals[fabricId] += amount;
    }

    return totals;
  }

  async findOne(id: string, userId: number): Promise<{
    gabarit: {
      id: string;
      name: string;
      description: String;
      originalImage: string | null;
      processedImage: string | null;
      iconPath: string | null;
      scale: number;
      favorited: boolean;
      createdAt: Date;
      updatedAt: Date;
      deletedAt?: Date;
    };
    pieces: Array<{
      id: number;
      name: string | null;
      outline: { points: { x: number; y: number }[] };
      area: number;
      NumberOfPieces: number | null;
      fabricId: string | null;
      createdAt: Date;
      updatedAt: Date;
      deletedAt?: Date;
    }>;
    totalPieces: number;
    imageDimensions: { width: number; height: number } | null;
  }> {
    const gabarit = await this.gabaritRepository.findOne({
      where: { id, user: { id: userId } },
      relations: ['pieces', 'pieces.fabric'],
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }

    // Build return gabarit sans user
    const gabaritReturn = {
      id: gabarit.id,
      name: gabarit.name,
      description: gabarit.description,
      originalImage: gabarit.originalImage ?? null,
      processedImage: gabarit.processedImage ?? null,
      iconPath: gabarit.iconPath ?? null,
      scale: gabarit.scale,
      favorited: gabarit.favorited,
      createdAt: gabarit.createdAt,
      updatedAt: gabarit.updatedAt,
      deletedAt: gabarit.deletedAt,
    };

    // Map pieces with fabricId only
    const piecesReturn = (gabarit.pieces || []).map((p) => ({
      id: p.id,
      name: p.name ?? null,
      outline: p.outline,
      area: p.area,
      NumberOfPieces: p.NumberOfPieces ?? 1,
  fabricId: (p as any).fabric?.id ?? null,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      deletedAt: p.deletedAt,
    }));

    // Try to compute image dimensions from processed or original image
    let imageDimensions: { width: number; height: number } | null = null;
    const sourceRel = gabarit.processedImage || gabarit.originalImage;
    if (sourceRel) {
      const abs = path.join(process.cwd(), sourceRel);
      if (fs.existsSync(abs)) {
        try {
          const meta = await sharp(abs).metadata();
          if (meta.width && meta.height) {
            imageDimensions = { width: meta.width, height: meta.height } as any;
          }
        } catch {}
      }
    }
    console.log({
      gabarit: gabaritReturn,
      pieces: piecesReturn,
      totalPieces: piecesReturn.length,
      imageDimensions,
    });
    return {
      gabarit: gabaritReturn,
      pieces: piecesReturn,
      totalPieces: piecesReturn.length,
      imageDimensions,
    };
  }

  async findGabaritsByUser(
    userId: number,
    start: number,
    limit: number
  ): Promise<any[]> {
    const gabarits = await this.gabaritRepository.find({
      where: { user: { id: Number(userId) } },
      skip: start,
      take: limit,
    });

    return gabarits.map(gabarit => {
      const processed = gabarit.processedImage ? path.basename(gabarit.processedImage) : null;
      const icon =  gabarit.iconPath ? path.basename(gabarit.iconPath) : null;
      
      return {
        id: gabarit.id,
        name: gabarit.name,
        scale: gabarit.scale,
        imageUrl: processed ? `/uploads/gabarits/${processed}` : null,
        iconUrl : icon ? `/uploads/gabarits/${icon}` : null,
        favorited: gabarit.favorited,
        createdAt: gabarit.createdAt,        
      };
    });
  }

  async update(id: string, updateData: UpdateGabaritDto, userId: number): Promise<any> {
    console.log(updateData)
    const existingGabarit = await this.gabaritRepository.findOne({ 
      where: { id, user: { id: userId } },
    });
    
    if (!existingGabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }
    
    await this.gabaritRepository.update(id, updateData);
    return this.findOne(id, userId);
  }

  // Function to modify/regenerate only the icon from the existing original file
  async updateIcon(id: string, userId: number, iconOptions?: { width?: number, height?: number, quality?: number }): Promise<Gabarit> {
    const gabarit = await this.gabaritRepository.findOne({
      where: { id, user: { id: userId } },
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }

    if (!gabarit.processedImage && !gabarit.originalImage) {
      throw new NotFoundException(`No image found for gabarit with id ${id}`);
    }

    // Get file extension and base name from the existing file
  const iconSource = gabarit.processedImage || gabarit.originalImage;
  const fileExtension = path.extname(iconSource);
  const baseName = path.basename(iconSource, fileExtension);
    
    // Create new icon path
    const iconFileName = `${baseName}-icon${fileExtension}`;
    const iconFilePath = `uploads/gabarits/${iconFileName}`;
    
    // Full paths for file operations
  const fullOriginalPath = path.join(process.cwd(), iconSource);
    const fullIconPath = path.join(process.cwd(), iconFilePath);
    
    // Default icon options
    const width = iconOptions?.width || 200;
    const height = iconOptions?.height || 200;
    const quality = iconOptions?.quality || 80;
    
    try {
      // Delete old icon if it exists
      if (gabarit.iconPath) {
        const oldIconPath = path.join(process.cwd(), gabarit.iconPath);
        if (fs.existsSync(oldIconPath)) {
          fs.unlinkSync(oldIconPath);
        }
      }
      
      // Create new downscaled icon version using sharp from the existing original file
      await sharp(fullOriginalPath)
        .resize(width, height, {
          fit: 'cover',
          position: 'center'
        })
        .jpeg({ quality })
        .toFile(fullIconPath);
      
      // Update only the iconPath in the database
      await this.gabaritRepository.update(id, { iconPath: iconFilePath });
      
      // Return the updated gabarit
      const updatedGabarit = await this.gabaritRepository.findOne({
        where: { id, user: { id: userId } },
      });
      
      if (!updatedGabarit) {
        throw new NotFoundException(`Gabarit with id ${id} not found after update`);
      }
      
      return updatedGabarit;
      
    } catch (error) {
      // Clean up new icon file if there's an error
      if (fs.existsSync(fullIconPath)) {
        fs.unlinkSync(fullIconPath);
      }
      throw error;
    }
  }


  async softdelete(id: string, userId: number): Promise<void> {
    const gabarit = await this.gabaritRepository.findOne({
      where: { id, user: { id: userId } },
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }
    
    
    
    await this.gabaritRepository.softDelete(id);
  }

  // Override remove method to clean up files
  // DONT USE IT IS NOT SOFTDELETE
  //DONT USE
  async remove(id: string, userId: number): Promise<void> {
    const gabarit = await this.gabaritRepository.findOne({
      where: { id, user: { id: userId } },
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }

    // Delete the associated files (original, processed and icon)
    if (gabarit.originalImage) {
      const orig = path.join(process.cwd(), gabarit.originalImage);
      if (fs.existsSync(orig)) {
        fs.unlinkSync(orig);
      }
    }

    if (gabarit.processedImage) {
      const proc = path.join(process.cwd(), gabarit.processedImage);
      if (fs.existsSync(proc)) {
        fs.unlinkSync(proc);
      }
    }
    
    if (gabarit.iconPath) {
      const iconPath = path.join(process.cwd(), gabarit.iconPath);
      if (fs.existsSync(iconPath)) {
        fs.unlinkSync(iconPath);
      }
    }
    
    // Delete from database
    this.gabaritRepository.remove(gabarit);
  }

  async detectBorders(id: string, userId: number): Promise<Buffer> {
    // 1) Ensure the gabarit exists and belongs to the requesting user
    const gabarit = await this.gabaritRepository.findOne({
      where: { id, user: { id: userId } },
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }

    // 2) Resolve the absolute path to the stored image
  const imageSource = gabarit.processedImage || gabarit.originalImage;
  const imagePath = path.join(process.cwd(), imageSource);
  if (!fs.existsSync(imagePath)) {
      throw new NotFoundException('Gabarit image file not found on disk');
    }

    // 3) Build multipart/form-data
    const form = new FormData();
    const filename = path.basename(imagePath);
    form.append('file', fs.createReadStream(imagePath), filename);

    // 4) Call the FastAPI service
    try {
  const url = `${this.getBaseUrl()}/process-gabarit`;
      const response = await axios.post(
        url,
        form,
        {
          headers: {
            ...form.getHeaders(),
            Accept: 'image/png',
          },
          responseType: 'arraybuffer',
          timeout: 15000,
        }
      );

  const data = response.data as ArrayBuffer; 
  return Buffer.from(data);
    } catch (err: any) {
      const status = err?.response?.status;
      const detail = err?.response?.data?.detail || err?.message || 'Unknown error';
      throw new Error(`Border detection failed${status ? ` (${status})` : ''}: ${detail}`);
    }
  }

  // Consolidated: process via FastAPI, persist processed image & icon, upsert pieces, return metadata
  async processAndPersist(gabaritId: string, userId: number, fabricId?: string): Promise<{
    gabarit: {
      id: string;
      name: string;
      description: String;
      originalImage: string | null;
      processedImage: string | null;
      iconPath: string | null;
      scale: number;
      favorited: boolean;
      createdAt: Date;
      updatedAt: Date;
      deletedAt?: Date;
    };
    pieces: Array<{
      id: number;
      name: string | null;
      outline: { points: { x: number; y: number }[] };
      area: number;
      NumberOfPieces: number | null;
      fabricId: string | null;
      createdAt: Date;
      updatedAt: Date;
      deletedAt?: Date;
    }>;
    totalPieces: number;
    imageDimensions: { width: number; height: number };
  }> {
    // 1) Find the gabarit and verify ownership
    const gabarit = await this.gabaritRepository.findOne({
      where: { id: gabaritId, user: { id: userId } },
      relations: ['user', 'pieces'],
    });

    if (!gabarit) {
      throw new NotFoundException('Gabarit not found or access denied');
    }

    // 2) Resolve the absolute path to the stored image
  const originalImagePath = path.join(process.cwd(), gabarit.originalImage);
    if (!fs.existsSync(originalImagePath)) {
      throw new NotFoundException('Gabarit image file not found on disk');
    }

    // 3) Build multipart/form-data
    const form = new FormData();
    const filename = path.basename(originalImagePath);
    form.append('file', fs.createReadStream(originalImagePath), filename);

    // 4) Call the FastAPI /gabarit-full service
  const url = `${this.getBaseUrl()}/gabarit-full`;
    const response = await axios.post(
      url,
      form,
      {
        headers: {
          ...form.getHeaders(),
          Accept: 'application/json',
        },
        timeout: 30000,
      }
    );

    const responseData = response.data as {
      processed_image: string; // data URL or base64
      gabarit_pieces: Array<{
        piece_id: number;
        area: number;
        perimeter: number;
        bounding_box: { x: number; y: number; width: number; height: number };
        centroid: { x: number; y: number };
        solidity: number;
        aspect_ratio: number;
        vertices_count: number;
        contour_points: [number, number][];
        hull_points: [number, number][];
        approximate_polygon: [number, number][];
      }>;
      total_pieces: number;
      image_dimensions: { width: number; height: number };
    };

    // 5) Save processed image to disk as a new file next to originals
    let base64 = responseData.processed_image;
    if (base64.startsWith('data:image/')) {
      base64 = base64.split(',')[1];
    }
    const buffer = Buffer.from(base64, 'base64');

    const uploadsDir = path.join(process.cwd(), 'uploads', 'gabarits');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const timeSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const processedFilename = `gabarit-${timeSuffix}-processed.png`;
    const processedRelPath = path.join('uploads', 'gabarits', processedFilename).replace(/\\/g, '/');
    const processedAbsPath = path.join(process.cwd(), processedRelPath);
    fs.writeFileSync(processedAbsPath, buffer);

    // 6) Do NOT regenerate icon here. Only update the processed image on the gabarit
    const oldFileAbs = gabarit.processedImage ? path.join(process.cwd(), gabarit.processedImage) : undefined;
    const originalAbs = gabarit.originalImage ? path.join(process.cwd(), gabarit.originalImage) : undefined;

    gabarit.processedImage = processedRelPath;
    await this.gabaritRepository.save(gabarit);

    // Clean up old processed file (optional)
    if (oldFileAbs && fs.existsSync(oldFileAbs) && (!originalAbs || path.resolve(oldFileAbs) !== path.resolve(originalAbs))) {
      try { fs.unlinkSync(oldFileAbs); } catch {}
    }

    // 8) Upsert pieces: remove existing then insert new set
    if (gabarit.pieces && gabarit.pieces.length > 0) {
      const existingIds = gabarit.pieces.map(p => p.id).filter(Boolean);
      if (existingIds.length > 0) {
        await this.pieceRepository.softDelete({ id: In(existingIds) });
      }
    }

    // If a fabricId is provided, validate it belongs to the user
    let linkedFabric: Fabric | null = null;
    if (fabricId) {
      linkedFabric = await this.fabricRepository.findOne({
        where: { id: fabricId, user: { id: userId } as any },
        relations: ['user'],
      });
      if (!linkedFabric) {
        // If invalid, ignore linking rather than failing the whole process
        linkedFabric = null;
      }
    }

    const newPieces: Piece[] = responseData.gabarit_pieces.map(p => {
      const piece = new Piece();
      // Set relation using id object to ensure FK is set reliably
      piece.gabarit = { id: gabarit.id } as any;
      piece.name = `Piece ${p.piece_id}` as any;
      piece.outline = {
        points: (p.contour_points || []).map(([x, y]) => ({ x, y })),
      } as any;
      // Use area from endpoint if valid; otherwise compute from contour points
      const endpointArea = Number(p.area);
      const areaToUse = Number.isFinite(endpointArea) && endpointArea > 0
        ? endpointArea
        : this.computePolygonArea(p.contour_points || []);
      piece.area = Math.round(areaToUse);
      piece.NumberOfPieces = 1;
      if (linkedFabric) {
        // assign relation by reference; no need to reload later
        piece.fabric = { id: linkedFabric.id } as any;
      }
      return piece;
    });
    const savedPieces = await this.pieceRepository.save(newPieces);

    // 9) Return entity-shaped data (exclude user). Include fabricId only for pieces
    const gabaritReturn = {
      id: gabarit.id,
      name: gabarit.name,
      description: gabarit.description,
      originalImage: gabarit.originalImage ?? null,
      processedImage: gabarit.processedImage ?? null,
      iconPath: gabarit.iconPath ?? null,
      scale: gabarit.scale,
      favorited: gabarit.favorited,
      createdAt: gabarit.createdAt,
      updatedAt: gabarit.updatedAt,
      deletedAt: gabarit.deletedAt,
    };

    const piecesReturn = savedPieces.map(sp => ({
      id: sp.id,
      name: sp.name ?? null,
      outline: sp.outline,
      area: sp.area,
      NumberOfPieces: sp.NumberOfPieces ?? 1,
      // Ensure fabricId is returned if present; fall back to the provided linked fabric (if any)
      fabricId: (sp as any).fabric?.id ?? linkedFabric?.id ?? null,
      createdAt: sp.createdAt,
      updatedAt: sp.updatedAt,
      deletedAt: sp.deletedAt,
    }));
    console.log(gabaritReturn.iconPath);

    return {
      gabarit: gabaritReturn,
      pieces: piecesReturn,
      totalPieces: responseData.total_pieces,
      imageDimensions: responseData.image_dimensions,
    };
  }

}
