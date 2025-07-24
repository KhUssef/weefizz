import { PartialType } from '@nestjs/mapped-types';
import { CreateGabaritDto } from './create-gabarit.dto';

export class UpdateGabaritDto extends PartialType(CreateGabaritDto) {}
