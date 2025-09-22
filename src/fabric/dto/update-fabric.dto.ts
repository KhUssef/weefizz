import { PartialType } from '@nestjs/mapped-types';
import { CreateFabricDto } from './create-fabric.dto';
import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateFabricDto  {

    @IsString()
    @IsOptional()
    type?: string;

    @IsString()
    @IsOptional()
    title?: string;

    @IsString()
    @IsOptional()
    description?: string;

    @IsString()
    @IsOptional()
    color?: string;

    @IsOptional()
    @IsBoolean()
    favorited?: boolean;

    @IsString()
    @IsOptional()
    filePath?: string;  

    @IsString()
    @IsOptional()
    iconPath?: string;
}
