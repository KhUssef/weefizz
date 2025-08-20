import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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

@Injectable()
export class GabaritService {
  constructor(
    @InjectRepository(Gabarit)
    private readonly gabaritRepository: Repository<Gabarit>,
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
      
      // Create downscaled icon version using sharp from the existing file
      await sharp(fullOriginalPath)
        .resize(200, 200, { // Resize to 200x200 pixels
          fit: 'cover', // Maintain aspect ratio and crop if necessary
          position: 'center'
        })
        .jpeg({ quality: 80 }) // Convert to JPEG with 80% quality
        .toFile(fullIconPath);
      
      // Create the gabarit entity with both file paths
      const gabarit = this.gabaritRepository.create({
        ...createGabaritDto,
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
  
  // Custom update method to handle file replacement
  //NEVER USRED BASICALLY
  async updateWithFile(id: string, userId: number, updateData: Partial<Gabarit>, newFilePath?: string): Promise<Gabarit> {
    const existingGabarit = await this.gabaritRepository.findOne({
      where: { id: id, user: { id: userId } },
    });
    if (!existingGabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }
    
    // If new file is provided, process it and delete old files
    if (newFilePath && existingGabarit.filePath) {
      // Get file extension and base name from the new file (already has unique name from controller)
      const fileExtension = path.extname(newFilePath);
      const baseName = path.basename(newFilePath, fileExtension);
      
      // Create icon path by adding '-icon' suffix to the existing unique filename
      const iconFileName = `${baseName}-icon${fileExtension}`;
      const iconFilePath = `uploads/gabarits/${iconFileName}`;
      
      // Full paths for file operations
      const fullNewPath = path.join(process.cwd(), newFilePath);
      const fullIconPath = path.join(process.cwd(), iconFilePath);
      
      try {
        // Create downscaled icon version using sharp from the new file
        await sharp(fullNewPath)
          .resize(200, 200, {
            fit: 'cover',
            position: 'center'
          })
          .jpeg({ quality: 80 })
          .toFile(fullIconPath);
        
        // Delete old files
        const oldFilePath = path.join(process.cwd(), existingGabarit.filePath);
        const oldIconPath = path.join(process.cwd(), existingGabarit.iconPath);
        
        if (fs.existsSync(oldFilePath)) {
          fs.unlinkSync(oldFilePath);
        }
        if (fs.existsSync(oldIconPath)) {
          fs.unlinkSync(oldIconPath);
        }
        
        // Update both file paths
        updateData.filePath = newFilePath;
        updateData.iconPath = iconFilePath;
        
      } catch (error) {
        // Clean up icon file if there's an error (keep new original file)
        if (fs.existsSync(fullIconPath)) {
          fs.unlinkSync(fullIconPath);
        }
        throw error;
      }
    }
    
    this.gabaritRepository.merge(existingGabarit, updateData);
    return this.gabaritRepository.save(existingGabarit);
  }

  async findOne(id: string, userId: number): Promise<any> {
    const gabarit = await this.gabaritRepository.findOne({ 
      where: { id, user: { id: userId } }, 
    });
    if (!gabarit) {
      throw new NotFoundException(`Gabarit with id ${id} not found or you don't have access to it`);
    }
    
    // Convert file paths to URLs
    const originalFilename = gabarit.filePath ? path.basename(gabarit.filePath) : null;
    const iconFilename = gabarit.iconPath ? path.basename(gabarit.iconPath) : null;
    
    return {
      ...gabarit,
      originalImageUrl: originalFilename ? `/gabarit/image/${originalFilename}` : null,
      iconImageUrl: iconFilename ? `/gabarit/image/${iconFilename}` : null,
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
      const imagePath =gabarit.filePath;
      const iconPath =  gabarit.iconPath
      
      return {
        id: gabarit.id,
        name: gabarit.name,
        scale: gabarit.scale,
        imageUrl: imagePath ? imagePath : null,
        iconUrl : iconPath ? iconPath : null,
        favorited: gabarit.favorited,
        createdAt: gabarit.createdAt,        
      };
    });
  }

  async update(id: string, updateData: Partial<Gabarit>, userId: number): Promise<any> {
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

    if (!gabarit.filePath) {
      throw new NotFoundException(`No original file found for gabarit with id ${id}`);
    }

    // Get file extension and base name from the existing file
    const fileExtension = path.extname(gabarit.filePath);
    const baseName = path.basename(gabarit.filePath, fileExtension);
    
    // Create new icon path
    const iconFileName = `${baseName}-icon${fileExtension}`;
    const iconFilePath = `uploads/gabarits/${iconFileName}`;
    
    // Full paths for file operations
    const fullOriginalPath = path.join(process.cwd(), gabarit.filePath);
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

    // Delete the associated files (both original and icon)
    if (gabarit.filePath) {
      const filePath = path.join(process.cwd(), gabarit.filePath);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
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
    const imagePath = path.join(process.cwd(), gabarit.filePath);
    if (!fs.existsSync(imagePath)) {
      throw new NotFoundException('Gabarit image file not found on disk');
    }

    // 3) Build multipart/form-data
    const form = new FormData();
    const filename = path.basename(imagePath);
    form.append('file', fs.createReadStream(imagePath), filename);

    // 4) Call the FastAPI service
    try {
  const response = await axios.post(
        'http://127.0.0.1:8000/process-gabarit',
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

  async processGabaritFull(gabaritId: string, userId: number): Promise<{
    processedImage: Buffer;
    gabaritPieces: any[];
    totalPieces: number;
    imageDimensions: { width: number; height: number };
  }> {
    // 1) Find the gabarit and verify ownership
    const gabarit = await this.gabaritRepository.findOne({
      where: { id: gabaritId, user: { id: userId } },
      relations: ['user'],
    });

    if (!gabarit) {
      throw new NotFoundException('Gabarit not found or access denied');
    }

    // 2) Resolve the absolute path to the stored image
    const imagePath = path.join(process.cwd(), gabarit.filePath);
    if (!fs.existsSync(imagePath)) {
      throw new NotFoundException('Gabarit image file not found on disk');
    }

    // 3) Build multipart/form-data
    const form = new FormData();
    const filename = path.basename(imagePath);
    form.append('file', fs.createReadStream(imagePath), filename);

    // 4) Call the FastAPI /gabarit-full service
    try {
      const response = await axios.post(
        'http://127.0.0.1:8000/gabarit-full',
        form,
        {
          headers: {
            ...form.getHeaders(),
            Accept: 'application/json',
          },
          timeout: 30000, // Increased timeout for more complex processing
        }
      );

      const responseData = response.data as {
        processed_image: string;
        gabarit_pieces: any[];
        total_pieces: number;
        image_dimensions: { width: number; height: number };
      };

      
      
      const base64Data = responseData.processed_image.replace(/^data:image\/png;base64,/, '');
      const processedImageBuffer = Buffer.from(base64Data, 'base64');
      
      console.log('✅ Converted buffer length:', processedImageBuffer.length);
      console.log('✅ Buffer first 10 bytes:', Array.from(processedImageBuffer.slice(0, 10)));

      return {
        processedImage: processedImageBuffer,
        gabaritPieces: responseData.gabarit_pieces,
        totalPieces: responseData.total_pieces,
        imageDimensions: responseData.image_dimensions,
      };
    } catch (err: any) {
      const status = err?.response?.status;
      const detail = err?.response?.data?.error || err?.message || 'Unknown error';
      throw new Error(`Gabarit full processing failed${status ? ` (${status})` : ''}: ${detail}`);
    }
  }

  async processGabaritFullImageOnly(gabaritId: string, userId: number): Promise<Buffer> {
    // 1) Find the gabarit and verify ownership
    const gabarit = await this.gabaritRepository.findOne({
      where: { id: gabaritId, user: { id: userId } },
      relations: ['user'],
    });

    if (!gabarit) {
      throw new NotFoundException('Gabarit not found or access denied');
    }

    // 2) Resolve the absolute path to the stored image
    const imagePath = path.join(process.cwd(), gabarit.filePath);
    if (!fs.existsSync(imagePath)) {
      throw new NotFoundException('Gabarit image file not found on disk');
    }

    // 3) Build multipart/form-data
    const form = new FormData();
    const filename = path.basename(imagePath);
    form.append('file', fs.createReadStream(imagePath), filename);

    // 4) Call the FastAPI service and get JSON response
    try {
      const response = await axios.post(
        'http://127.0.0.1:8000/gabarit-full',
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
        processed_image: string;
        gabarit_pieces: any[];
        total_pieces: number;
        image_dimensions: { width: number; height: number };
      };

      // 5) Extract and convert base64 to buffer
      let base64Data = responseData.processed_image;
      
      // Remove data URL prefix if present
      if (base64Data.startsWith('data:image/')) {
        base64Data = base64Data.split(',')[1];
      }
      
      const imageBuffer = Buffer.from(base64Data, 'base64');
      
      console.log('🎯 Direct conversion - Buffer length:', imageBuffer.length);
      
      return imageBuffer;
    } catch (err: any) {
      const status = err?.response?.status;
      const detail = err?.response?.data?.error || err?.message || 'Unknown error';
      throw new Error(`Gabarit image processing failed${status ? ` (${status})` : ''}: ${detail}`);
    }
  }

}
