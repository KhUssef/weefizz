import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BaseService } from '../common/generic.service'; 
import { Fabric } from './entities/fabric.entity';
import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { SafeUserDto } from '../user/dto/safe-user.dto';
import { CreateFabricDto } from './dto/create-fabric.dto';

@Injectable()
export class FabricService extends BaseService<Fabric> {
  constructor(
    @InjectRepository(Fabric)
    private fabricRepository: Repository<Fabric>,
  ) {
    super(fabricRepository); 
  }

  // Helper method to transform fabric data with safe user info
  private transformFabricWithSafeUser(fabric: Fabric): any {
    return {
      ...fabric,
      user: new SafeUserDto(fabric.user)
    };
  }

  // Helper method to transform array of fabrics with safe user info
  private transformFabricsWithSafeUser(fabrics: Fabric[]): any[] {
    return fabrics.map(fabric => this.transformFabricWithSafeUser(fabric));
  }

  async create(data: Partial<Fabric>): Promise<any> {
    const entity = this.fabricRepository.create(data);
    const savedFabric = await this.fabricRepository.save(entity);
    return this.findOne(savedFabric.id);
  }

  async createWithUserId(fabricData: CreateFabricDto & { filePath: string }, userId: number): Promise<any> {
    const entity = this.fabricRepository.create({
      ...fabricData,
      user: { id: userId } as any,
    });
    const savedFabric = await this.fabricRepository.save(entity);
    return this.findOne(savedFabric.id);
  }

  async findAll(): Promise<any[]> {
    const fabrics = await this.fabricRepository.find({ relations: ['user'] });
    return this.transformFabricsWithSafeUser(fabrics);
  }

  private async findOneRaw(id: string): Promise<Fabric> {
    const fabric = await this.fabricRepository.findOne({ 
      where: { id }, 
      relations: ['user'] 
    });
    if (!fabric) {
      throw new NotFoundException(`Fabric with id ${id} not found`);
    }
    return fabric;
  }

  async findOne(id: string): Promise<any> {
    const fabric = await this.findOneRaw(id);
    return this.transformFabricWithSafeUser(fabric);
  }

  async updateWithOwnership(id: string, updateData: Partial<Fabric>, userId: number, newFilePath?: string): Promise<any> {
    const existingFabric = await this.findOneRaw(id);
    
    if (existingFabric.user.id !== userId) {
      throw new ForbiddenException('You can only update your own fabrics');
    }
    
    // If new file is provided, delete the old file
    if (newFilePath && existingFabric.filePath) {
      const fs = require('fs');
      const path = require('path');
      const oldFilePath = path.join(process.cwd(), existingFabric.filePath);
      
      // Delete old file if it exists
      if (fs.existsSync(oldFilePath)) {
        fs.unlinkSync(oldFilePath);
      }
      
      updateData.filePath = newFilePath;
    }
    
    await this.update(id, updateData);
    return this.findOne(id); 
  }

  // Override remove method with ownership check and file cleanup
  async removeWithOwnership(id: string, userId: number): Promise<void> {
    const fabric = await this.findOneRaw(id);
    
    // Check ownership
    if (fabric.user.id !== userId) {
      throw new ForbiddenException('You can only delete your own fabrics');
    }
    
    // Delete the associated file
    if (fabric.filePath) {
      const fs = require('fs');
      const path = require('path');
      const filePath = path.join(process.cwd(), fabric.filePath);
      
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    
    // Call parent remove method
    return super.remove(id);
  }

  // Find fabrics by color (only user's own fabrics)
  async findByColorForUser(color: string, userId: number): Promise<any[]> {
    const fabrics = await this.fabricRepository.find({ 
      where: { color, user: { id: userId } },
      relations: ['user']
    });
    return this.transformFabricsWithSafeUser(fabrics);
  }

  // Find fabrics for a specific user (only if it's the same user)
  async findFabricsByUser(userId: string, requestingUserId: number): Promise<any[]> {
    if (Number(userId) !== requestingUserId) {
      throw new ForbiddenException('You can only view your own fabrics');
    }
    
    const fabrics = await this.fabricRepository.find({
      where: { user: { id: Number(userId) } },
      relations: ['user'], 
    });
    return this.transformFabricsWithSafeUser(fabrics);
  }
}
