import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GabaritService } from './gabarit.service';
import { GabaritController } from './gabarit.controller';
import { Gabarit } from './entities/gabarit.entity';
import { User } from '../user/entities/user.entity';
import { Piece } from '../piece/entities/piece.entity';
import { Fabric } from '../fabric/entities/fabric.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Gabarit, User, Piece, Fabric])],
  controllers: [GabaritController],
  providers: [GabaritService],
  exports: [GabaritService],
})
export class GabaritModule {}
