import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { EmailService } from '../email/email.service';

@Processor('email')
export class EmailProcessor extends WorkerHost {
  private readonly logger = new Logger(EmailProcessor.name);

  constructor(private readonly email: EmailService) {
    super();
  }

  async process(job: Job<{ to: string; subject: string; text?: string }>) {
    this.logger.log(`email job ${job.id} → ${job.data.to} | ${job.data.subject}`);
    await this.email.send(
      job.data.to,
      job.data.subject,
      job.data.text ?? '',
    );
  }
}
