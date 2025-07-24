import { Controller, Post, Get, Put, Delete, Body, Param, UseGuards, Req } from '@nestjs/common';
import { Request } from 'express';
import { FabricService } from './fabric.service';
import { Fabric } from './entities/fabric.entity'; 
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('fabric')
export class FabricController {
  constructor(private readonly fabricService: FabricService,) {}

@UseGuards(JwtAuthGuard)
@Post()
async create(@Body() fabricDto: Partial<Fabric>, @Req() req: Request): Promise<Fabric> {
  const user = req.user; 
  const fabricWithUser = { ...fabricDto, user };
  return this.fabricService.create(fabricWithUser);
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

