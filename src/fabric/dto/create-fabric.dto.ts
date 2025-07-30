import { IsString, IsInt, Min, IsNotEmpty, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateFabricDto {
  @IsString()
  @IsNotEmpty()
  color: string;

  @Transform(({ value }) => parseInt(value))
  @IsInt()
  @Min(0)
  quantity: number;

  @IsString()
  @IsNotEmpty()
  type: string; 
  
  // filePath will be set automatically after file upload
  @IsOptional()
  @IsString()
  filePath?: string;
}
