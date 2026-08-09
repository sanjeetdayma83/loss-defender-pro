import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

/** Must match BullModule.registerQueue name: 'notify' */
@Processor('notify')
export class NotificationProcessor extends WorkerHost {
  private readonly logger = new Logger(NotificationProcessor.name);

  async process(job: Job) {
    this.logger.log(`notify job ${job.id} ${JSON.stringify(job.data)}`);
  }
}
