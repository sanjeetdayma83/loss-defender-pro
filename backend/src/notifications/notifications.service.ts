import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { QUEUE_EMAIL, QUEUE_NOTIFICATION } from '../queues/queue.constants';
import { NotificationChannel, NotificationStatus } from '@prisma/client';
import { EventsGateway } from '../realtime/events.gateway';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(QUEUE_NOTIFICATION) private readonly notifyQueue: Queue,
    @InjectQueue(QUEUE_EMAIL) private readonly emailQueue: Queue,
    private readonly events: EventsGateway,
  ) {}

  list(companyId: string, userId?: string) {
    return this.prisma.notification.findMany({
      where: {
        companyId,
        ...(userId ? { OR: [{ userId }, { userId: null }] } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async create(companyId: string, dto: CreateNotificationDto) {
    const row = await this.prisma.notification.create({
      data: {
        companyId,
        userId: dto.userId,
        channel: dto.channel as NotificationChannel,
        title: dto.title,
        body: dto.body,
        data: (dto.data as any) ?? undefined,
        status:
          dto.channel === 'in_app'
            ? NotificationStatus.sent
            : NotificationStatus.pending,
      },
    });

    try {
      this.events.emitNotification(companyId, {
        id: row.id,
        title: row.title,
        body: row.body,
        channel: row.channel,
      });
    } catch (_) {}

    if (dto.channel === 'email') {
      let to = 'noreply@localhost';
      if (dto.userId) {
        const u = await this.prisma.user.findFirst({
          where: { id: dto.userId, companyId },
        });
        if (u?.email) to = u.email;
      }
      await this.emailQueue.add('send', {
        to,
        subject: dto.title,
        text: dto.body,
      });
    } else if (dto.channel !== 'in_app') {
      await this.notifyQueue.add('deliver', {
        notificationId: row.id,
        channel: dto.channel,
        title: dto.title,
        body: dto.body,
      });
    }

    return row;
  }

  async markRead(companyId: string, id: string) {
    const row = await this.prisma.notification.findFirst({
      where: { id, companyId },
    });
    if (!row) throw new NotFoundException('Notification not found');
    return this.prisma.notification.update({
      where: { id },
      data: { status: NotificationStatus.read, readAt: new Date() },
    });
  }
}