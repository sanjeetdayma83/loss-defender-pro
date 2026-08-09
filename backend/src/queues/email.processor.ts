import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { QUEUE_EMAIL } from './queues.module';

@Processor(QUEUE_EMAIL)
export class EmailProcessor extends WorkerHost {
  private readonly logger = new Logger(EmailProcessor.name);
  async process(job: Job<{ to: string; subject: string; text?: string }>) {
    this.logger.log(`email job ${job.id} → ${job.data.to} | ${job.data.subject}`);
  }
}