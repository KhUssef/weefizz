import { Module } from '@nestjs/common';
import { PieceService } from './piece.service';
import { PieceController } from './piece.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Piece } from './entities/piece.entity';
import { Gabarit } from '../gabarit/entities/gabarit.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Piece, Gabarit])],
  controllers: [PieceController],
  providers: [PieceService],
})
export class PieceModule {}
