// app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import configuration from './config/configuration';
import { typeOrmConfig } from './config/typeorm.config';
import { AuthModule } from './auth/auth.module';
import { User } from './auth/decorator/user.decorator';
import { UserModule } from './user/user.module';
import { FabricModule } from './fabric/fabric.module';
import { GabaritModule } from './gabarit/gabarit.module';
import { PieceModule } from './piece/piece.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration], // 👈 load custom config
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: typeOrmConfig,
    }),
    AuthModule,
    UserModule,
    FabricModule,
    GabaritModule,
    PieceModule
  ],
})
export class AppModule {}
