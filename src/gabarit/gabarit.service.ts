import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateGabaritDto } from './dto/create-gabarit.dto';
import { UpdateGabaritDto } from './dto/update-gabarit.dto';
import { Gabarit } from './entities/gabarit.entity';
import { BaseService } from '../common/generic.service'; 
import { SafeUserDto } from '../user/dto/safe-user.dto'; 

@Injectable()
export class GabaritService extends BaseService<Gabarit> {
  constructor(
    @InjectRepository(Gabarit)
    private readonly gabaritRepository: Repository<Gabarit>,
  ) {
    super(gabaritRepository);
  }

  // Custom update method to handle file replacement
  async updateWithFile(id: string, updateData: Partial<Gabarit>, newFilePath?: string): Promise<Gabarit> {
    const existingGabarit = await this.findOne(id);
    
    // If new file is provided, delete the old file
    if (newFilePath && existingGabarit.filePath) {
      const fs = require('fs');
      const path = require('path');
      const oldFilePath = path.join(process.cwd(), existingGabarit.filePath);
      
      // Delete old file if it exists
      if (fs.existsSync(oldFilePath)) {
        fs.unlinkSync(oldFilePath);
      }
      
      updateData.filePath = newFilePath;
    }
    
    return this.update(id, updateData);
  }

  // Override remove method to clean up files
  async remove(id: string): Promise<void> {
    const gabarit = await this.findOne(id);
    
    // Delete the associated file
    if (gabarit.filePath) {
      const fs = require('fs');
      const path = require('path');
      const filePath = path.join(process.cwd(), gabarit.filePath);
      
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    
    // Call parent remove method
    return super.remove(id);
  }

  // Add custom gabarit-specific methods here if needed
}
