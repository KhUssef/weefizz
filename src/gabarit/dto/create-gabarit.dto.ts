import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class CreateGabaritDto {
  @IsString()
  @IsNotEmpty()
  name: string;
  
  // filePath will be set automatically after file upload
  @IsOptional()
  @IsString()
  filePath?: string;
}

