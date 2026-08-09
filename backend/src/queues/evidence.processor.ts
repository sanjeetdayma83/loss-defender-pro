import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

@Processor('evidence')
export class EvidenceProcessor extends WorkerHost {
  private readonly logger = new Logger(EvidenceProcessor.name);

  async process(job: Job) {
    this.logger.log(`evidence job ${job.id} ${JSON.stringify(job.data)}`);
  }
}
