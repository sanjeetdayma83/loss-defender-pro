import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { EvidenceService } from '../evidence/evidence.service';
@Processor('evidence')
export class EvidenceProcessor extends WorkerHost {
  private readonly logger = new Logger(EvidenceProcessor.name);
  constructor(private readonly evidence: EvidenceService) { super(); }
  async process(job: Job<{ companyId: string; recordingId: string; evidenceId: string }>) { this.logger.log(`processing evidence job ${job.id}`); return this.evidence.processRecordingEvidence(job.data.companyId, job.data.recordingId, job.data.evidenceId); }
}
