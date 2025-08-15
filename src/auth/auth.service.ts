import { Injectable, UnauthorizedException } from '@nestjs/common';
import { UserService } from '../user/user.service';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { ConfigService } from '@nestjs/config';
import { User } from 'src/user/entities/user.entity';
import { signupDTO } from './dto/signup.dto';

@Injectable()
export class AuthService {
  private accessSecret: string;
  private refreshSecret: string;
  private accessExpires: string;
  private refreshExpires: string;

  constructor(
    private usersService: UserService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {
    this.accessSecret = this.configService.get<string>('jwt.accessSecret')!;
    if (!this.accessSecret) {
      throw new Error('JWT_ACCESS_SECRET is not set');
    }

    this.refreshSecret = this.configService.get<string>('jwt.refreshSecret')!;
    if (!this.refreshSecret) {
      throw new Error('JWT_ACCESS_SECRET is not set');
    }

    this.accessExpires = this.configService.get<string>('jwt.accessExpires') || '15m';
    this.refreshExpires = this.configService.get<string>('jwt.refreshExpires') || '7d';
  }

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.usersService.findByEmail(email);
    if (user && await bcrypt.compare(password, user.password)) {
      const { password, ...result } = user;
      return result;
    }
    return null;
  }

  async login(user: any) {
    const payload = { email: user.email, sub: user.id };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.accessSecret,
      expiresIn: this.accessExpires,
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.refreshSecret,
      expiresIn: this.refreshExpires,
    });
    console.log('Access Token:', accessToken);
    console.log('Refresh Token:', refreshToken);
    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      username: user.username,
    };
  }
  async signup(signupDTO: signupDTO) {
    try {    
      const  existingUser = await this.usersService.findByEmail(signupDTO.email);
    } catch (error) {
      if (error.message !== 'User not found') {
        throw new UnauthorizedException('Error checking existing user');
      }
    }
    
    const hashedPassword = await bcrypt.hash(signupDTO.password, 10);
    const user = await this.usersService.create({
      email : signupDTO.email,
      username: signupDTO.username,
      isEmailVerified : false,
      password: hashedPassword,
    } as User);
    if(!user) {
      throw new UnauthorizedException('User registration failed');
      }
    }
  async refresh(refreshToken: string) {
    console.log('Received refresh token:', refreshToken);
    if (!refreshToken) {
      throw new UnauthorizedException('Refresh token must be provided');
    }
    try {
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: this.refreshSecret,
      });

      // Backward compatibility: if old tokens carried username, fetch email by sub
      let email = (payload as any).email as string | undefined;
      if (!email && (payload as any).username) {
        const user = await this.usersService.findOne(payload.sub);
        email = user.email;
      }
      if (!email) {
        const user = await this.usersService.findOne(payload.sub);
        email = user.email;
      }

      // Issue new access and refresh tokens with email in payload
      const newPayload = { email, sub: payload.sub };

      const newAccessToken = this.jwtService.sign(newPayload, {
        secret: this.accessSecret,
        expiresIn: this.accessExpires,
      });

      const newRefreshToken = this.jwtService.sign(newPayload, {
        secret: this.refreshSecret,
        expiresIn: this.refreshExpires,
      });

      return {
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
      };
    } catch (e) {
      console.error('Refresh token verification failed:', e);
      throw new UnauthorizedException('Invalid refresh token');
    }
  }
}
