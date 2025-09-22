import { IsInt, IsOptional, IsPositive, isString, IsString, Max, Min } from 'class-validator';

export class UpdatePieceDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(999)
  NumberOfPieces?: number;

  @IsOptional()
  @IsString()
  fabricId?: string;
}
