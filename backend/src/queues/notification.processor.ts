import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';

@Processor('notify')
export class NotificationProcessor extends WorkerHost {
  private readonly logger = new Logger(NotificationProcessor.name);
  constructor(private readonly prisma: PrismaService, private readonly email: EmailService) { super(); }

  async process(job: Job) {
    const { notificationId, channel, title, body } = job.data ?? {};
    if (!notificationId) return { skipped: true };
    const notification = await this.prisma.notification.findUnique({ where: { id: notificationId }, include: { user: true } });
    if (!notification) return { skipped: true, reason: 'notification-not-found' };
    try {
      switch (channel) {
        case 'email':
          if (!notification.user?.email) throw new Error('Notification user email missing');
          await this.email.sendGeneric(notification.user.email, title, body);
          break;
        case 'sms':
          if (!process.env.SMS_PROVIDER_URL) throw new Error('SMS provider is not configured');
          await this.callProvider(process.env.SMS_PROVIDER_URL, process.env.SMS_PROVIDER_TOKEN, { to: notification.user?.phone, title, body });
          break;
        case 'whatsapp':
          if (!process.env.WHATSAPP_PROVIDER_URL) throw new Error('WhatsApp provider is not configured');
          await this.callProvider(process.env.WHATSAPP_PROVIDER_URL, process.env.WHATSAPP_PROVIDER_TOKEN, { to: notification.user?.phone, title, body });
          break;
        case 'push':
          if (!process.env.PUSH_PROVIDER_URL) throw new Error('Push provider is not configured');
          await this.callProvider(process.env.PUSH_PROVIDER_URL, process.env.PUSH_PROVIDER_TOKEN, { userId: notification.userId, title, body, data: notification.data });
          break;
        default:
          return { skipped: true, reason: `unsupported-channel:${channel}` };
      }
      await this.prisma.notification.update({ where: { id: notificationId }, data: { status: 'sent' } });
      return { sent: true, notificationId, channel };
    } catch (e: any) {
      await this.prisma.notification.update({ where: { id: notificationId }, data: { status: 'failed' } });
      this.logger.error(`Notification ${notificationId} failed: ${e?.message ?? e}`);
      throw e;
    }
  }

  private async callProvider(url: string, token: string | undefined, payload: unknown) {
    const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(payload) });
    if (!response.ok) throw new Error(`Provider returned ${response.status}`);
  }
}
