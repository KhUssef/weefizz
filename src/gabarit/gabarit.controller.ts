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
  BadRequestException,
  Query,
  Res
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request, Response } from 'express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { GabaritService } from './gabarit.service';
import { CreateGabaritDto } from './dto/create-gabarit.dto';
import { UpdateGabaritDto } from './dto/update-gabarit.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { User } from 'src/auth/decorator/user.decorator';

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
      if (!file.originalname.match(/\.(jpg|jpeg|png)$/)) {
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
    @Req() req: Request,
    @User() user: any
  ) {
    if (!file) {
      throw new BadRequestException('Image file is required');
    }

    const gabaritData = {
      ...createGabaritDto,
      filePath: file.path,
    };

    return this.gabaritService.create(gabaritData, user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findAll(
    @User() user: any, 
    @Query("page") page: number=0, 
    @Query("limit") limit: number=10
  ) {
    const userId = user.id;
    const start = page * limit; // Convert page to start index
    return this.gabaritService.findGabaritsByUser(userId, start, limit);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  findOne(@Param('id') id: string, @User() user: any) {
    return this.gabaritService.findOne(id, user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(@Param('id') id: string, @Body() updateGabaritDto: UpdateGabaritDto, @User() user: any) {
    return this.gabaritService.update(id, updateGabaritDto, user.id);
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
      if (!file.originalname.match(/\.(jpg|jpeg|png)$/)) {
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
    @User() user: any,
    @UploadedFile() file?: Express.Multer.File,
    @Req() req?: Request
  ) {
    const newFilePath = file ? file.path : undefined;
    return this.gabaritService.updateWithFile(id, user.id, updateGabaritDto, newFilePath);
  }


  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Param('id') id: string, @User() user: any) {
    return this.gabaritService.softdelete(id, user.id);
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

  @UseGuards(JwtAuthGuard)
  @Get('detectborders/:id')
  async detectBorders(@Param('id') id: string, @User() user: any, @Res() res: Response) {
    const resultBuffer = await this.gabaritService.detectBorders(id, user.id);
    res.setHeader('Content-Type', 'image/png');
    res.send(resultBuffer);
  }

  @UseGuards(JwtAuthGuard)
  @Get('process-full/:id')
  async processGabaritFull(@Param('id') id: string, @User() user: any, @Res() res: Response) {
    const result = await this.gabaritService.processGabaritFull(id, user.id);
    
    // Set custom headers with the metadata (avoiding base64)
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('X-Gabarit-Total-Pieces', result.totalPieces.toString());
    res.setHeader('X-Gabarit-Image-Width', result.imageDimensions.width.toString());
    res.setHeader('X-Gabarit-Image-Height', result.imageDimensions.height.toString());
    res.setHeader('X-Gabarit-Pieces', JSON.stringify(result.gabaritPieces));
    
    // Return the actual image as binary
    return res.end(result.processedImage);
  }

  @UseGuards(JwtAuthGuard)
  @Get('process-full-info/:id')
  async processGabaritFullInfo(@Param('id') id: string, @User() user: any) {
    const result = await this.gabaritService.processGabaritFull(id, user.id);
    
    // Return only the metadata as JSON, with a URL to get the image
    return {
      gabaritPieces: result.gabaritPieces,
      totalPieces: result.totalPieces,
      imageDimensions: result.imageDimensions,
      processedImageUrl: `/gabarit/process-full-image/${id}`,
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('process-full-image/:id')
  async processGabaritFullImage(@Param('id') id: string, @User() user: any, @Res() res: Response) {
    try {
      const result = await this.gabaritService.processGabaritFull(id, user.id);
      
      // Debug: Log the buffer length
      console.log('📷 Processed image buffer length:', result.processedImage.length);
      
      // Set proper headers for image response
      res.setHeader('Content-Type', 'image/png');
      res.setHeader('Content-Length', result.processedImage.length);
      
      // Send the buffer directly
      return res.end(result.processedImage);
    } catch (error) {
      console.error('❌ Error in processGabaritFullImage:', error);
      throw error;
    }
  }
}
