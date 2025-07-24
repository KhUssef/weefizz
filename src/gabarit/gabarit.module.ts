import { Module } from '@nestjs/common';
import { GabaritService } from './gabarit.service';
import { GabaritController } from './gabarit.controller';

@Module({
  controllers: [GabaritController],
  providers: [GabaritService],
})
export class GabaritModule {}
