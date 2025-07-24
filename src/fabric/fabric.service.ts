import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BaseService } from '../common/generic.service'; 
import { Fabric } from './entities/fabric.entity';

@Injectable()
export class FabricService extends BaseService<Fabric> {
  constructor(
    @InjectRepository(Fabric)
    private fabricRepository: Repository<Fabric>,
  ) {
    super(fabricRepository); 
  }


  //a method to find fabrics by color
  async findByColor(color: string): Promise<Fabric[]> {
    return this.fabricRepository.find({ where: { color } });
  }

  // Find fabrics for a specific user
  async findFabricsByUser(userId: string): Promise<Fabric[]> {
    return this.fabricRepository.find({
      where: { user: { id: Number(userId) } },
      relations: ['user'], 
    });
  }
}
