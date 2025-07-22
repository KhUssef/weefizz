import { Controller, Post, Get, Put, Delete, Body, Param } from '@nestjs/common';
import { FabricService } from './fabric.service';
import { Fabric } from './entities/fabric.entity'; 

@Controller('fabric')
export class FabricController {
  constructor(private readonly fabricService: FabricService) {}

  @Post()
  create(@Body() fabricDto: Fabric): Promise<Fabric> {
    return this.fabricService.create(fabricDto);
  }

  @Get()
  findAll(): Promise<Fabric[]> {
    return this.fabricService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string): Promise<Fabric> {
    return this.fabricService.findOne(id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() fabricData: Partial<Fabric>): Promise<Fabric> {
    return this.fabricService.update(id, fabricData);
  }

  @Delete(':id')
  remove(@Param('id') id: string): Promise<void> {
    return this.fabricService.remove(id);
  }

    @Get('color/:color')
    findByColor(@Param('color') color: string): Promise<Fabric[]> {
        return this.fabricService.findByColor(color);
    }   

    @Get('user/:userId')
    findFabricsByUser(@Param('userId') userId: string): Promise<Fabric[]> {
        return this.fabricService.findFabricsByUser(userId);
    }
}
