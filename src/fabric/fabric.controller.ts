import { 
  Controller, 
  Post, 
  Get, 
  Put, 
  Delete, 
  Body, 
  Param, 
  UseGuards, 
  Req, 
  UseInterceptors, 
  UploadedFile, 
  BadRequestException 
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { FabricService } from './fabric.service';
import { CreateFabricDto } from './dto/create-fabric.dto';
import { UpdateFabricDto } from './dto/update-fabric.dto';
import { Fabric } from './entities/fabric.entity'; 
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('fabric')
export class FabricController {
  constructor(private readonly fabricService: FabricService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  @UseInterceptors(FileInterceptor('image', {
    storage: diskStorage({
      destination: './uploads/fabrics',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        const filename = `fabric-${uniqueSuffix}${ext}`;
        callback(null, filename);
      },
    }),
    fileFilter: (req, file, callback) => {
      if (!file.originalname.match(/\.(jpg|jpeg|png|gif)$/)) {
        return callback(new BadRequestException('Only image files are allowed!'), false);
      }
      callback(null, true);
    },
    limits: {
      fileSize: 5 * 1024 * 1024, // 5MB limit
    },
  }))
  async create(
    @Body() createFabricDto: CreateFabricDto,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request
  ): Promise<any> {
    if (!file) {
      throw new BadRequestException('Image file is required');
    }

    const userId = (req.user as any).id;
    
    const fabricData = {
      ...createFabricDto,
      filePath: file.path,
    };

    return this.fabricService.createWithUserId(fabricData, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findAll(@Req() req: Request): Promise<any[]> {
    const userId = (req.user as any).id;
    return this.fabricService.findFabricsByUser(userId.toString(), userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  async findOne(@Param('id') id: string, @Req() req: Request): Promise<any> {
    const fabric = await this.fabricService.findOne(id);
    const userId = (req.user as any).id;
    
    // Check ownership
    if (fabric.user.id !== userId) {
      throw new BadRequestException('You can only view your own fabrics');
    }
    
    return fabric;
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  update(
    @Param('id') id: string, 
    @Body() updateFabricDto: UpdateFabricDto,
    @Req() req: Request
  ): Promise<any> {
    const userId = (req.user as any).id;
    return this.fabricService.updateWithOwnership(id, updateFabricDto, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id/with-image')
  @UseInterceptors(FileInterceptor('image', {
    storage: diskStorage({
      destination: './uploads/fabrics',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        const filename = `fabric-${uniqueSuffix}${ext}`;
        callback(null, filename);
      },
    }),
    fileFilter: (req, file, callback) => {
      if (!file.originalname.match(/\.(jpg|jpeg|png|gif)$/)) {
        return callback(new BadRequestException('Only image files are allowed!'), false);
      }
      callback(null, true);
    },
    limits: {
      fileSize: 5 * 1024 * 1024, // 5MB limit
    },
  }))
  async updateWithImage(
    @Param('id') id: string,
    @Body() updateFabricDto: UpdateFabricDto,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request
  ): Promise<any> {
    const userId = (req.user as any).id;
    const newFilePath = file ? file.path : undefined;
    return this.fabricService.updateWithOwnership(id, updateFabricDto, userId, newFilePath);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Param('id') id: string, @Req() req: Request): Promise<void> {
    const userId = (req.user as any).id;
    return this.fabricService.removeWithOwnership(id, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('color/:color')
  findByColor(@Param('color') color: string, @Req() req: Request): Promise<any[]> {
    const userId = (req.user as any).id;
    return this.fabricService.findByColorForUser(color, userId);
  }   

  @UseGuards(JwtAuthGuard)
  @Get('user/:userId')
  findFabricsByUser(@Param('userId') userId: string, @Req() req: Request): Promise<any[]> {
    const requestingUserId = (req.user as any).id;
    return this.fabricService.findFabricsByUser(userId, requestingUserId);
  }

  @Get('image/:filename')
  getImage(@Param('filename') filename: string): any {
    const path = require('path');
    const fs = require('fs');
    const filePath = path.join(process.cwd(), 'uploads', 'fabrics', filename);
    
    if (fs.existsSync(filePath)) {
      return { url: `/fabric/image/${filename}` };
    }
    throw new BadRequestException('Image not found');
  }
}

