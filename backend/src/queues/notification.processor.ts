import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { QUEUE_NOTIFICATION } from './queues.module';

@Processor(QUEUE_NOTIFICATION)
export class NotificationProcessor extends WorkerHost {
  private readonly logger = new Logger(NotificationProcessor.name);
  async process(job: Job<{ channel: string; title: string; body: string }>) {
    this.logger.log(`notify job ${job.id} [${job.data.channel}] ${job.data.title}`);
  }
}