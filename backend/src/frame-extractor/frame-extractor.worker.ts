import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { FrameExtractorService, FrameExtractionOptions } from './frame-extractor.service';
import { QUEUE_FRAME_EXTRACTION, FrameExtractionJobData, FrameExtractionJobResult } from './queue.constants';
import { PrismaService } from '../prisma/prisma.service';
import { EvidenceService } from '../evidence/evidence.service';

@Processor(QUEUE_FRAME_EXTRACTION)
@Injectable()
export class FrameExtractorWorker extends WorkerHost {
  private readonly logger = new Logger(FrameExtractorWorker.name);

  constructor(
    private readonly frameExtractor: FrameExtractorService,
    private readonly prisma: PrismaService,
    private readonly evidenceService: EvidenceService,
  ) {
    super();
  }

  async process(job: Job<FrameExtractionJobData, FrameExtractionJobResult, string>): Promise<FrameExtractionJobResult> {
    const { evidenceId, companyId, videoPath, options } = job.data;
    this.logger.log(`Starting frame extraction for evidence ${evidenceId}`);

    try {
      // Update evidence status to pending (processing reflected in metadata)
      await this.prisma.evidence.update({
        where: { id: evidenceId },
        data: {
          status: 'pending',
          metadata: {
            processingStatus: 'extracting_frames',
            startedAt: new Date().toISOString(),
          } as any,
        },
      });

      // Extract frames
      const result = await this.frameExtractor.extractFrames({
        videoPath,
        maxFrames: options?.maxFrames ?? 50,
        thumbnailSize: options?.thumbnailSize ?? '320x240',
      });

      // Update evidence with extracted frames
      const frames = result.frames.map((f) => ({
        index: f.index,
        label: f.label,
        type: f.type,
        path: f.path,
        size: f.size,
      }));

      await this.prisma.evidence.update({
        where: { id: evidenceId },
        data: {
          frameCount: result.frameCount,
          status: 'ready',
          metadata: {
            frames,
            processingStatus: 'completed',
            completedAt: new Date().toISOString(),
            duration: result.duration,
          } as any,
        },
      });

      this.logger.log(`Frame extraction completed for evidence ${evidenceId}: ${result.frameCount} frames`);
      return result;
    } catch (error) {
      this.logger.error(`Frame extraction failed for evidence ${evidenceId}: ${error.message}`);
      
      // Update evidence with error status
      await this.prisma.evidence.update({
        where: { id: evidenceId },
        data: {
          status: 'failed',
          metadata: {
            processingStatus: 'failed',
            error: error.message,
            failedAt: new Date().toISOString(),
          } as any,
        },
      });
      throw error;
    }
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job) {
    this.logger.log(`Frame extraction job ${job.id} completed`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, err: Error) {
    this.logger.error(`Frame extraction job ${job.id} failed: ${err.message}`);
  }
}