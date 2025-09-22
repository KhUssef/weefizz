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
  BadRequestException, 
  Query,
  ParseBoolPipe,
  ParseIntPipe,
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
import { User } from 'src/auth/decorator/user.decorator';
import { userInfo } from 'os';
// removed duplicate import of Parse pipes
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

  // Identify endpoint: takes an image, creates a Fabric with predetermined test data,
  // then returns a simple identification result (type + confidence)
  @UseGuards(JwtAuthGuard)
  @Post('identify')
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
      if (!file.originalname.match(/\.(jpg|jpeg|png)$/)) {
        return callback(new BadRequestException('Only image files are allowed!'), false);
      }
      callback(null, true);
    },
    limits: {
      fileSize: 5 * 1024 * 1024, // 5MB limit
    },
  }))
  async identify(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request
  ): Promise<{ fabric: any; predictions: Array<{ type: string; confidence?: number }> }> {
    if (!file) {
      throw new BadRequestException('Image file is required');
    }

  const userId = (req.user as any).id;
  const { fabric, predictions } = await this.fabricService.identifyFromImage(file.path, userId);
  return { fabric, predictions };
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findAll(
    @Req() req: Request, 
    @User() user: any, 
    @Query('downsized', new ParseBoolPipe({ optional: true })) downsized = true,
    @Query("page", new ParseIntPipe({ optional: true })) page: number=0, 
    @Query("limit", new ParseIntPipe({ optional: true })) limit: number=10
  ): Promise<any[]> {
    const userId = user.id;
    const start = page * limit; // Convert page to start index
    return this.fabricService.findFabricsByUser(userId, downsized, start, limit);
  }

  // Search fabrics by keyword (title or type), same pagination model
  @UseGuards(JwtAuthGuard)
  @Get('search')
  search(
    @User() user: any,
    @Query('q') q: string,
    @Query('downsized') downsized: boolean = true,
    @Query('page') page: number = 0,
    @Query('limit') limit: number = 10,
  ): Promise<any[]> {
    const userId = user.id;
    const start = page * limit;
    return this.fabricService.searchFabricsByUser(userId, q?.trim() || '', downsized, start, limit);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  async findOne(@Param('id') id: string, @Req() req: Request, @User() user: any): Promise<any> {
    const fabric = await this.fabricService.findOne(id, user.id);    
    return fabric;
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  update(
    @Param('id') id: string, 
    @Body() updateFabricDto: UpdateFabricDto,
    @Req() req: Request,
    @User() user: any
  ): Promise<any> {
    const userId = user.id;
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
  remove(@Param('id') id: string, @Req() req: Request, @User() user: any): Promise<void> {
    const userId = user.id;
    return this.fabricService.removeWithOwnership(id, userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('color/:color')
  findByColor(@Param('color') color: string, @Req() req: Request): Promise<any[]> {
    const userId = (req.user as any).id;
    return this.fabricService.findByColorForUser(color, userId);
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

  @Post('test-upload')
@UseInterceptors(FileInterceptor('image'))
async testUpload(@Req() req: Request) {
  return { body: req.body, file: (req as any).file };
}



}

