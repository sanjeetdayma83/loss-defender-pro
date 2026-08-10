import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { EmailModule } from '../email/email.module';
import { EvidenceModule } from '../evidence/evidence.module';
import { PrismaModule } from '../prisma/prisma.module';
import { EmailProcessor } from './email.processor';
import { EvidenceProcessor } from './evidence.processor';
import { NotificationProcessor } from './notification.processor';
import { QUEUE_EMAIL, QUEUE_EVIDENCE, QUEUE_NOTIFICATION } from './queue.constants';
export { QUEUE_EMAIL, QUEUE_EVIDENCE, QUEUE_NOTIFY, QUEUE_NOTIFICATION } from './queue.constants';
@Module({
  imports: [PrismaModule, EmailModule, EvidenceModule, BullModule.registerQueue({ name: QUEUE_EMAIL }, { name: QUEUE_EVIDENCE }, { name: QUEUE_NOTIFICATION })],
  providers: [EmailProcessor, EvidenceProcessor, NotificationProcessor],
  exports: [BullModule, EmailModule],
})
export class QueuesModule {}
