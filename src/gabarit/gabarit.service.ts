import { Injectable } from '@nestjs/common';
import { CreateGabaritDto } from './dto/create-gabarit.dto';
import { UpdateGabaritDto } from './dto/update-gabarit.dto';

@Injectable()
export class GabaritService {
  create(createGabaritDto: CreateGabaritDto) {
    return 'This action adds a new gabarit';
  }

  findAll() {
    return `This action returns all gabarit`;
  }

  findOne(id: number) {
    return `This action returns a #${id} gabarit`;
  }

  update(id: number, updateGabaritDto: UpdateGabaritDto) {
    return `This action updates a #${id} gabarit`;
  }

  remove(id: number) {
    return `This action removes a #${id} gabarit`;
  }
}
