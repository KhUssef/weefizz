import { Module } from '@nestjs/common';
import { PieceService } from './piece.service';
import { PieceController } from './piece.controller';

@Module({
  controllers: [PieceController],
  providers: [PieceService],
})
export class PieceModule {}
