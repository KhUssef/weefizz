import { 
  Controller, 
  Get, 
  Post, 
  Body, 
  Patch, 
  Param, 
  Delete, 
  UseInterceptors, 
  UploadedFile, 
  UseGuards,
  Req,
  BadRequestException 
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { GabaritService } from './gabarit.service';
import { CreateGabaritDto } from './dto/create-gabarit.dto';
import { UpdateGabaritDto } from './dto/update-gabarit.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('gabarit')
export class GabaritController {
  constructor(private readonly gabaritService: GabaritService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  @UseInterceptors(FileInterceptor('image', {
    storage: diskStorage({
      destination: './uploads/gabarits',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        const filename = `gabarit-${uniqueSuffix}${ext}`;
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
    @Body() createGabaritDto: CreateGabaritDto,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request
  ) {
    if (!file) {
      throw new BadRequestException('Image file is required');
    }

    const user = req.user;
    const gabaritData = {
      ...createGabaritDto,
      filePath: file.path,
      user
    };

    return this.gabaritService.create(gabaritData);
  }

  @Get()
  findAll() {
    return this.gabaritService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.gabaritService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateGabaritDto: UpdateGabaritDto) {
    return this.gabaritService.update(id, updateGabaritDto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/with-image')
  @UseInterceptors(FileInterceptor('image', {
    storage: diskStorage({
      destination: './uploads/gabarits',
      filename: (req, file, callback) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = extname(file.originalname);
        const filename = `gabarit-${uniqueSuffix}${ext}`;
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
    @Body() updateGabaritDto: UpdateGabaritDto,
    @UploadedFile() file?: Express.Multer.File,
    @Req() req?: Request
  ) {
    const newFilePath = file ? file.path : undefined;
    return this.gabaritService.updateWithFile(id, updateGabaritDto, newFilePath);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.gabaritService.remove(id);
  }
  
  @Get('image/:filename')
  getImage(@Param('filename') filename: string, @Req() req: Request) {
    const path = require('path');
    const fs = require('fs');
    const filePath = path.join(process.cwd(), 'uploads', 'gabarits', filename);
    
    if (fs.existsSync(filePath)) {
      return { url: `/gabarit/image/${filename}` };
    }
    throw new BadRequestException('Image not found');
  }
}
