import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ cors: { origin: '*' }, namespace: '/realtime' })
export class EventsGateway implements OnGatewayConnection {
  private readonly logger = new Logger(EventsGateway.name);

  @WebSocketServer()
  server: Server;

  handleConnection(client: Socket) {
    const companyId =
      (client.handshake.auth?.companyId as string) ||
      (client.handshake.query?.companyId as string);
    if (companyId) {
      client.join(`company:${companyId}`);
      this.logger.log(`${client.id} → company:${companyId}`);
    }
  }

  @SubscribeMessage('join')
  onJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { companyId?: string },
  ) {
    if (body?.companyId) {
      client.join(`company:${body.companyId}`);
      return { ok: true, room: `company:${body.companyId}` };
    }
    return { ok: false };
  }

  emitOrderStatus(companyId: string, payload: Record<string, unknown>) {
    this.server?.to(`company:${companyId}`).emit('order.status', payload);
  }

  emitNotification(companyId: string, payload: Record<string, unknown>) {
    this.server?.to(`company:${companyId}`).emit('notification', payload);
  }
}