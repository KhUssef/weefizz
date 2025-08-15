import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BaseService } from '../common/generic.service'; 
import { Fabric } from './entities/fabric.entity';
import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { SafeUserDto } from '../user/dto/safe-user.dto';
import { CreateFabricDto } from './dto/create-fabric.dto';
import * as sharp from 'sharp';
import * as path from 'path';
import * as fs from 'fs';

@Injectable()
export class FabricService{
  constructor(
    @InjectRepository(Fabric)
    private fabricRepository: Repository<Fabric>,
  ) {
  }

  async create(data: Partial<Fabric>): Promise<any> {
    const entity = this.fabricRepository.create(data);
    const savedFabric = await this.fabricRepository.save(entity);
    // Return the saved fabric directly since we don't have userId context here
    return savedFabric;
  }

  async   createWithUserId(fabricData: CreateFabricDto & { filePath: string }, userId: number): Promise<any> {
    // Get file extension and base name from the already unique file path
    const fileExtension = path.extname(fabricData.filePath);
    const baseName = path.basename(fabricData.filePath, fileExtension);

    if(fabricData.title==null){
      fabricData.title = fabricData.type
    }
    
    // Create icon path by adding '-icon' suffix to the existing unique filename
    const iconFileName = `${baseName}-icon${fileExtension}`;
    const iconFilePath = `uploads/fabrics/${iconFileName}`;
    
    // Full paths for file operations
    const fullOriginalPath = path.join(process.cwd(), fabricData.filePath);
    const fullIconPath = path.join(process.cwd(), iconFilePath);
    
    try {
      // Ensure the uploads/fabrics directory exists
      const uploadsDir = path.join(process.cwd(), 'uploads/fabrics');
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
      
      // Create the fabric entity with both file paths
      const entity = this.fabricRepository.create({
        ...fabricData,
        iconPath: iconFilePath,
        user: { id: userId } as any,
      });
      
      const savedFabric = await this.fabricRepository.save(entity);
      return this.findOne(savedFabric.id, userId);

    } catch (error) {
      // Clean up icon file if there's an error (keep original file)
      if (fs.existsSync(fullIconPath)) {
        fs.unlinkSync(fullIconPath);
      }
      throw error;
    }
  } 
  //  async findAll(): Promise<any[]> {
  //   const fabrics = await this.fabricRepository.find({ relations: ['user'] });
  //   return this.transformFabricsWithSafeUser(fabrics);
  // }

  async findOne(id: string, userId: number): Promise<any> {
    const fabric = await this.fabricRepository.findOne({ 
      where: { id, user: { id: userId } }, 
    });
    if (!fabric) {
      throw new NotFoundException(`Fabric with id ${id} not found or you don't have access to it`);
    }
    
    // Convert file paths to URLs
    const originalFilename = fabric.filePath ? path.basename(fabric.filePath) : null;
    const iconFilename = fabric.iconPath ? path.basename(fabric.iconPath) : null;
    
    return {
      id: fabric.id,
      title: fabric.title,
      description: fabric.description,
      color: fabric.color,
      createdAt: fabric.createdAt,
      type: fabric.type,
      imageUrl: iconFilename ? `/uploads/fabrics/${iconFilename}` : null,
    };
  }

  async updateWithOwnership(id: string, updateData: Partial<Fabric>, userId: number, newFilePath?: string): Promise<any> {

    if(updateData.user) {
      if(updateData.user.id!== userId)
        throw new ForbiddenException('You cannot change the user of a fabric');
    }
    const existingFabric = await this.fabricRepository.findOne({ 
      where: { id, user: { id: userId } },
    });
    
    if (!existingFabric) {
      throw new NotFoundException(`Fabric with id ${id} not found or you don't have access to it`);
    }
    
    // If new file is provided, process it and delete old files
    if (newFilePath && existingFabric.filePath) {
      // Get file extension and base name from the new file (already has unique name from controller)
      const fileExtension = path.extname(newFilePath);
      const baseName = path.basename(newFilePath, fileExtension);
      
      // Create icon path by adding '-icon' suffix to the existing unique filename
      const iconFileName = `${baseName}-icon${fileExtension}`;
      const iconFilePath = `uploads/fabrics/${iconFileName}`;
      
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
        const oldFilePath = path.join(process.cwd(), existingFabric.filePath);
        const oldIconPath = path.join(process.cwd(), existingFabric.iconPath);
        
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
        if (fs.existsSync(fullIconPath)) {
          fs.unlinkSync(fullIconPath);
        }
        throw error;
      }
    }
    
    await this.fabricRepository.update(id, updateData);
    return this.findOne(id, userId); 
  }

  async delete(id:string, userid: number){
    const fabric = await this.fabricRepository.findOne({
      where: { id, user: { id: userid } },
    })
    if(!fabric) {
      throw new NotFoundException(`Fabric with id ${id} not found or you don't have access to it`);
    }
    this.fabricRepository.softDelete(id); // Soft delete the fabric
  }

  // Override remove method with ownership check and file cleanup
  async removeWithOwnership(id: string, userId: number): Promise<void> {
    const fabric = await this.fabricRepository.findOne({ 
      where: { id, user: { id: userId } },
      relations: ['user']
    });
    
    if (!fabric) {
      throw new NotFoundException(`Fabric with id ${id} not found or you don't have access to it`);
    }
    
    // Delete the associated files (both original and icon)
    // DONT USE 
    // NOT SOFT DELETE NOT WORTH IT  
    if (fabric.filePath) {
      const filePath = path.join(process.cwd(), fabric.filePath);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    
    if (fabric.iconPath) {
      const iconPath = path.join(process.cwd(), fabric.iconPath);
      if (fs.existsSync(iconPath)) {
        fs.unlinkSync(iconPath);
      }
    }
    
    // Delete the fabric from database
    await this.fabricRepository.delete(id);
  }

  // Find fabrics by color (only user's own fabrics)
  async findByColorForUser(color: string, userId: number): Promise<any[]> {
    const fabrics = await this.fabricRepository.find({ 
      where: { color, user: { id: userId } },
    });
    return fabrics;
  }

async findFabricsByUser(
  userId: number,
  downsized = true,
  start = 0,
  limit = 10,
): Promise<any[]> {
  const fabrics = await this.fabricRepository.find({
    where: { user: { id: Number(userId) } },
    order: { favorited: 'DESC', createdAt: 'DESC' },
    skip: start,
    take: limit,
  });

  return fabrics.map(fabric => {
    const imagePath = downsized ? fabric.iconPath : fabric.filePath;
    const filename = imagePath ? path.basename(imagePath) : null;

    return {
      id: fabric.id,
      type: fabric.type,
      color: fabric.color,
      imageUrl: filename ? `/uploads/fabrics/${filename}` : null, 
      favorited: fabric.favorited,
      createdAt: fabric.createdAt,
      title: fabric.title
    };
  });
}

  async searchFabricsByUser(
    userId: number,
    keyword: string,
    downsized = true,
    start = 0,
    limit = 10,
  ): Promise<any[]> {
    const qb = this.fabricRepository.createQueryBuilder('fabric');
    qb.where('fabric.userId = :userId', { userId });

    if (keyword) {
      qb.andWhere(
        '(LOWER(fabric.title) LIKE :kw OR LOWER(fabric.type) LIKE :kw)',
        { kw: `%${keyword.toLowerCase()}%` },
      );
    }

    qb.orderBy('fabric.favorited', 'DESC')
      .skip(start)
      .take(limit);

    const fabrics = await qb.getMany();

    return fabrics.map((fabric) => {
      const imagePath = downsized ? fabric.iconPath : fabric.filePath;
      const filename = imagePath ? path.basename(imagePath) : null;

      return {
        id: fabric.id,
        type: fabric.type,
        color: fabric.color,
        title: fabric.title,
        imageUrl: filename ? `/uploads/fabrics/${filename}` : null,
        favorited: fabric.favorited,
        createdAt: fabric.createdAt,
      };
    });
  }
}
