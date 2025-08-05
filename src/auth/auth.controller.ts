import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LocalAuthGuard } from './local-auth.guard';
import { loginDTO } from './dto/login.dto';
import { signupDTO } from './dto/signup.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}
  @UseGuards(LocalAuthGuard)
  @Post()
  login(@Body() loginDTO: loginDTO) {

    return this.authService.login(loginDTO);
  }

  @UseGuards(JwtAuthGuard)
  @Post("hey")
  hey() {
    console.log("Hey there!");
    return "Hey there!";
  }

  @Post('refresh')
  refresh(@Body() body: { refresh_token: string }) {
    return this.authService.refresh(body.refresh_token);
  }
  
  @Post('signup')
  register(@Body() signupDTO: signupDTO) {
    return this.authService.signup(signupDTO);
  }

}
