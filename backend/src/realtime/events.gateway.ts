import { ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ cors: { origin: process.env.FRONTEND_ORIGIN?.split(',') ?? false }, namespace: '/realtime' })
export class EventsGateway implements OnGatewayConnection {
  private readonly logger = new Logger(EventsGateway.name);
  @WebSocketServer() server: Server;

  constructor(private readonly jwt: JwtService) {}

  handleConnection(client: Socket) {
    try {
      const token = String(client.handshake.auth?.token ?? client.handshake.headers.authorization?.replace(/^Bearer\s+/i, '') ?? '');
      if (!token) throw new UnauthorizedException('WebSocket token required');
      const payload: any = this.jwt.verify(token, { secret: process.env.JWT_ACCESS_SECRET ?? 'dev-access' });
      if (!payload?.sub || !payload?.companyId) throw new UnauthorizedException('Invalid websocket token');
      client.data.userId = payload.sub;
      client.data.companyId = payload.companyId;
      client.data.role = payload.role;
      client.join(`company:${payload.companyId}`);
      this.logger.log(`${client.id} authenticated → company:${payload.companyId}`);
    } catch (e: any) {
      this.logger.warn(`Rejected websocket ${client.id}: ${e?.message ?? e}`);
      client.disconnect(true);
    }
  }

  @SubscribeMessage('join')
  onJoin(@ConnectedSocket() client: Socket, @MessageBody() body: { companyId?: string }) {
    if (!client.data.companyId || body?.companyId !== client.data.companyId) return { ok: false, error: 'Forbidden' };
    client.join(`company:${client.data.companyId}`);
    return { ok: true, room: `company:${client.data.companyId}` };
  }

  emitOrderStatus(companyId: string, payload: Record<string, unknown>) { this.server?.to(`company:${companyId}`).emit('order.status', payload); }
  emitNotification(companyId: string, payload: Record<string, unknown>) { this.server?.to(`company:${companyId}`).emit('notification', payload); }
}
