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
  Res,
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
  update(
    @Param('id') id: string,
    @Body() updateGabaritDto: UpdateGabaritDto,
    @User() user: any,
    @Req() req: Request,
  ) {
    // Debug: log full incoming request details and body

    return this.gabaritService.update(id, updateGabaritDto, user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/with-image')
  @UseInterceptors(FileInterceptor('file', {
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

  // Consolidated processing endpoint: runs full processing, persists results, returns metadata
  @UseGuards(JwtAuthGuard)
  @Get('process/:id')
  async processGabarit(
    @Param('id') id: string,
    @User() user: any,
    @Query('fabricId') fabricId?: string,
  ) {
    const result = await this.gabaritService.processAndPersist(id, user.id, fabricId);
  // Return entity-shaped payload without user, include fabricId for pieces
  return result;
  }

  // Calculate required fabric amounts per fabric for a given gabarit and multiplier `number`
  @UseGuards(JwtAuthGuard)
  @Get('calcul/:id')
  async calculateFabricAmounts(
    @Param('id') id: string,
    @Query('number') numberParam: string,
    @User() user: any,
  ) {
    const n = Number(numberParam);
    if (!numberParam || Number.isNaN(n) || n <= 0) {
      throw new BadRequestException('Query parameter "number" must be a positive number');
    }
    return this.gabaritService.calculateFabricRequirements(id, user.id, n);
  }
}
