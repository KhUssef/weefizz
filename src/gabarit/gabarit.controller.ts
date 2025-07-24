import { Controller, Get, Post, Body, Patch, Param, Delete } from '@nestjs/common';
import { GabaritService } from './gabarit.service';
import { CreateGabaritDto } from './dto/create-gabarit.dto';
import { UpdateGabaritDto } from './dto/update-gabarit.dto';

@Controller('gabarit')
export class GabaritController {
  constructor(private readonly gabaritService: GabaritService) {}

  @Post()
  create(@Body() createGabaritDto: CreateGabaritDto) {
    return this.gabaritService.create(createGabaritDto);
  }

  @Get()
  findAll() {
    return this.gabaritService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.gabaritService.findOne(+id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateGabaritDto: UpdateGabaritDto) {
    return this.gabaritService.update(+id, updateGabaritDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.gabaritService.remove(+id);
  }
}
