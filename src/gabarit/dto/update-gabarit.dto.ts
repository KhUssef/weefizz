import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class UpdateGabaritDto {
    @IsOptional()
    @IsString()
    name?: string;

    @IsOptional()
    @IsString()
    description?: string;

    @IsOptional()
    @IsNumber()
    @Min(0)
    scale?: number;

    @IsOptional()
    @IsBoolean()
    favorited?: boolean;

    @IsOptional()
    @IsString()
    file?: string;
}
