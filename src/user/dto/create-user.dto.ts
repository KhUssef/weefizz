import { IsBoolean, IsEmail, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateUserDto {
	@IsString()
	@IsNotEmpty()
	username!: string;

	@IsEmail()
	@IsNotEmpty()
	email!: string;

	@IsString()
	@MinLength(6)
	@IsNotEmpty()
	password!: string;

	@IsBoolean()
	@IsOptional()
	isEmailVerified?: boolean;
}
