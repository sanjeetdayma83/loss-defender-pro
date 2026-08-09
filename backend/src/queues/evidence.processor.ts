import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { QUEUE_EVIDENCE } from './queues.module';

@Processor(QUEUE_EVIDENCE)
export class EvidenceProcessor extends WorkerHost {
  private readonly logger = new Logger(EvidenceProcessor.name);
  async process(job: Job<{ recordingId: string; evidenceId: string }>) {
    this.logger.log(
      `evidence job ${job.id} recording=${job.data.recordingId} evidence=${job.data.evidenceId}`,
    );
    // Future: ffmpeg frame extract from B2 segment
  }
}