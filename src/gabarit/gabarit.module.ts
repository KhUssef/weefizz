import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GabaritService } from './gabarit.service';
import { GabaritController } from './gabarit.controller';
import { Gabarit } from './entities/gabarit.entity';
import { User } from '../user/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Gabarit, User])],
  controllers: [GabaritController],
  providers: [GabaritService],
  exports: [GabaritService],
})
export class GabaritModule {}
