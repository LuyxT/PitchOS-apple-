import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

@WebSocketGateway({
  namespace: '/messages/realtime',
  cors: { origin: '*' },
})
export class MessengerGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async handleConnection(client: Socket): Promise<void> {
    const token = client.handshake.auth?.token ?? client.handshake.query?.token;
    if (!token || typeof token !== 'string') {
      client.disconnect();
      return;
    }

    try {
      const payload = this.jwtService.verify(token, {
        secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
      const userId = payload.sub;
      client.join(`user:${userId}`);
      client.data.userId = userId;
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(_client: Socket): void {}

  @SubscribeMessage('ping')
  onPing(@ConnectedSocket() client: Socket, @MessageBody() body: unknown) {
    client.emit('pong', body);
  }

  publishToChat(chatId: string, event: string, payload: unknown): void {
    this.server.to(`chat:${chatId}`).emit(event, payload);
  }

  publishToUsers(userIds: string[], event: string, payload: unknown): void {
    for (const userId of userIds) {
      this.server.to(`user:${userId}`).emit(event, payload);
    }
  }

  attachSocketToChat(socket: Socket, chatId: string): void {
    socket.join(`chat:${chatId}`);
  }
}
