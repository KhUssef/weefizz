import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UserService } from '../user/user.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private userService: UserService
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(), 
      secretOrKey: configService.get<string>('jwt.accessSecret'),
      ignoreExpiration: false, // Reject expired tokens
    });
  }

  async validate(payload: any) {

    const user = await this.userService.findOne(payload.sub);
    
    // Return only safe, non-sensitive user data
    return {
      id: user.id,
      username: user.username,
      email: user.email
    };
  }
}
