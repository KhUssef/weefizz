import { Controller } from '@nestjs/common';
import { PieceService } from './piece.service';

@Controller('piece')
export class PieceController {
  constructor(private readonly pieceService: PieceService) {}
}
