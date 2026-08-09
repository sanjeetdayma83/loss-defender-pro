import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { QUEUE_EVIDENCE } from './queues.module';
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

@Processor(QUEUE_EVIDENCE)
export class EvidenceProcessor extends WorkerHost {
  private readonly logger = new Logger(EvidenceProcessor.name);

  async process(job: Job<{ recordingId: string; evidenceId: string; localPath?: string }>) {
    this.logger.log(`evidence job ${job.id} rec=${job.data.recordingId}`);
    if (!job.data.localPath) {
      this.logger.warn('No localPath — skip ffmpeg (segment frames already linked)');
      return { skipped: true, reason: 'no_local_path' };
    }
    try {
      await execFileAsync('ffmpeg', ['-version']);
    } catch {
      this.logger.warn('ffmpeg not in PATH — skip frame extract');
      return { skipped: true, reason: 'no_ffmpeg' };
    }
    // Future: extract + upload frames to B2
    this.logger.log('ffmpeg available — extract pipeline TODO');
    return { skipped: false, note: 'hook_ready' };
  }
}