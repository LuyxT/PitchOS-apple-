import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MessengerController } from './messenger.controller';
import { MessengerService } from './messenger.service';
import { MessengerGateway } from './messenger.gateway';

@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
      }),
    }),
  ],
  controllers: [MessengerController],
  providers: [MessengerService, MessengerGateway],
  exports: [MessengerService, MessengerGateway],
})
export class MessengerModule {}
