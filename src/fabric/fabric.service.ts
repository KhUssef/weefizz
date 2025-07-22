import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BaseService } from '../common/generic.service'; // Adjust path as needed
import { Fabric } from './entities/fabric.entity'; // Adjust path as needed

@Injectable()
export class FabricService extends BaseService<Fabric> {
  constructor(
    @InjectRepository(Fabric)
    private fabricRepository: Repository<Fabric>,
  ) {
    super(fabricRepository); // Pass the injected repository to the BaseService constructor
  }

  // You can add Fabric-specific methods here if needed
  // For example, a method to find fabrics by color
  async findByColor(color: string): Promise<Fabric[]> {
    return this.fabricRepository.find({ where: { color } });
  }

  // Example: Find fabrics for a specific user
  async findFabricsByUser(userId: string): Promise<Fabric[]> {
    return this.fabricRepository.find({
      where: { user: { id: Number(userId) } },
      relations: ['user'], // Eager load the user if needed
    });
  }
}
