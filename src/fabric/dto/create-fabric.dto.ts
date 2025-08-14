import { IsString, IsInt, Min, IsNotEmpty, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateFabricDto {
  @IsString()
  @IsNotEmpty()
  color: string;

  @IsString()
  @IsNotEmpty()
  type: string; 
  
  // filePath will be set automatically after file upload
  @IsOptional()
  @IsString()
  filePath?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  title?: string;
}
