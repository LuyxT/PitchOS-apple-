import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ namespace: '/widgets/live', cors: { origin: '*' } })
export class WidgetsGateway {
  @WebSocketServer()
  server!: Server;

  @SubscribeMessage('subscribe')
  subscribe(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body: { teamId: string; size: 'small' | 'medium' | 'large' },
  ) {
    socket.join(`widgets:${body.teamId}:${body.size}`);
    return { ok: true };
  }

  publish(teamId: string, size: 'small' | 'medium' | 'large', payload: unknown) {
    this.server.to(`widgets:${teamId}:${size}`).emit('widgets.update', payload);
  }
}
