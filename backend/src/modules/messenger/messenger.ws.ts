import { WebSocketServer, WebSocket } from 'ws';
import type { Server } from 'http';
import type { IncomingMessage } from 'http';
import { URL } from 'url';
import { verifyAccessToken, signAccessToken } from '../../lib/jwt';
import { logger } from '../../config/logger';
import { getPrisma } from '../../lib/prisma';
import crypto from 'crypto';

class MessengerHub {
  private wss: WebSocketServer | null = null;
  private clients: Map<string, Set<WebSocket>> = new Map();

  attach(server: Server, jwtSecret: string) {
    this.wss = new WebSocketServer({ noServer: true });

    server.on('upgrade', (req: IncomingMessage, socket, head) => {
      const url = new URL(req.url || '', `http://${req.headers.host}`);

      if (url.pathname !== '/messages/realtime') {
        socket.destroy();
        return;
      }

      const token = url.searchParams.get('token');
      if (!token) {
        socket.destroy();
        return;
      }

      try {
        const payload = verifyAccessToken(token, jwtSecret);
        this.wss!.handleUpgrade(req, socket, head, (ws) => {
          this.addClient(payload.userId, ws);
          this.wss!.emit('connection', ws, req);
        });
      } catch {
        socket.destroy();
      }
    });

    this.wss.on('connection', (ws: WebSocket) => {
      ws.on('close', () => {
        this.removeClient(ws);
      });

      ws.on('error', () => {
        this.removeClient(ws);
      });

      // Respond to pings from client
      ws.on('pong', () => { });
    });

    // Heartbeat every 30 seconds
    setInterval(() => {
      if (!this.wss) return;
      for (const ws of this.wss.clients) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.ping();
        }
      }
    }, 30_000);
  }

  private addClient(userId: string, ws: WebSocket) {
    let sockets = this.clients.get(userId);
    if (!sockets) {
      sockets = new Set();
      this.clients.set(userId, sockets);
    }
    sockets.add(ws);
    logger.info('WebSocket client connected', { userId, totalClients: this.totalClients() });
  }

  private removeClient(ws: WebSocket) {
    for (const [userId, sockets] of this.clients.entries()) {
      sockets.delete(ws);
      if (sockets.size === 0) {
        this.clients.delete(userId);
      }
    }
  }

  private totalClients(): number {
    let count = 0;
    for (const sockets of this.clients.values()) {
      count += sockets.size;
    }
    return count;
  }

  /** Broadcast a realtime event to specific user IDs. */
  broadcastToUsers(userIds: string[], event: object) {
    const payload = JSON.stringify(event);
    for (const userId of userIds) {
      const sockets = this.clients.get(userId);
      if (!sockets) continue;
      for (const ws of sockets) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(payload);
        }
      }
    }
  }

  /** Broadcast a message event to all participants of a chat. */
  async broadcastMessageCreated(chatId: string, messageDTO: object) {
    const prisma = getPrisma();
    const participants = await prisma.messengerParticipant.findMany({
      where: { chatId },
      select: { userId: true },
    });

    const userIds = participants.map((p) => p.userId);
    const cursor = crypto.randomUUID();

    this.broadcastToUsers(userIds, {
      eventCursor: cursor,
      type: 'message.created',
      chat: null,
      message: messageDTO,
      chatID: chatId,
      messageID: null,
    });
  }

  /** Broadcast a message deletion event to all participants of a chat. */
  async broadcastMessageDeleted(chatId: string, messageId: string) {
    const prisma = getPrisma();
    const participants = await prisma.messengerParticipant.findMany({
      where: { chatId },
      select: { userId: true },
    });

    const userIds = participants.map((p) => p.userId);
    const cursor = crypto.randomUUID();

    this.broadcastToUsers(userIds, {
      eventCursor: cursor,
      type: 'message.deleted',
      chat: null,
      message: null,
      chatID: chatId,
      messageID: messageId,
    });
  }

  /** Generate a short-lived realtime token. */
  generateRealtimeToken(
    userId: string,
    email: string,
    role: string,
    secret: string
  ): { token: string; expiresAt: string } {
    const token = signAccessToken({ userId, email, role }, secret, '5m');
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
    return { token, expiresAt };
  }
}

export const messengerHub = new MessengerHub();
