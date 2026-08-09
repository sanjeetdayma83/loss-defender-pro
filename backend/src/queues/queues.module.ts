import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { EmailModule } from '../email/email.module';
import { EmailProcessor } from './email.processor';
import { EvidenceProcessor } from './evidence.processor';
import { NotificationProcessor } from './notification.processor';

export const QUEUE_EMAIL = 'email';
export const QUEUE_EVIDENCE = 'evidence';
export const QUEUE_NOTIFY = 'notify';
export const QUEUE_NOTIFICATION = 'notify';

@Module({
  imports: [
    EmailModule,
    BullModule.forRoot({
      connection: {
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: Number(process.env.REDIS_PORT || 6379),
      },
    }),
    BullModule.registerQueue(
      { name: 'email' },
      { name: 'evidence' },
      { name: 'notify' },
    ),
  ],
  providers: [EmailProcessor, EvidenceProcessor, NotificationProcessor],
  exports: [BullModule, EmailModule],
})
export class QueuesModule {}
