import { Body, Controller, Param, Patch, UseGuards } from '@nestjs/common';
import { PieceService } from './piece.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdatePieceDto } from './dto/update-piece.dto';
import { User } from 'src/auth/decorator/user.decorator';

@Controller('piece')
export class PieceController {
  constructor(private readonly pieceService: PieceService) {}

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdatePieceDto,
    @User() user: any,
  ) {
    return this.pieceService.update(Number(id), user.id, dto);
  }
}
