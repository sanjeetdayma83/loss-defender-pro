import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { warehouseScope, assertWarehouseAccess } from '../common/utils/warehouse-scope';
import { Queue } from 'bullmq';
import { InjectQueue } from '@nestjs/bullmq';
import { QUEUE_FRAME_EXTRACTION, FrameExtractionJobData } from '../frame-extractor/queue.constants';

@Injectable()
export class EvidenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    @InjectQueue(QUEUE_FRAME_EXTRACTION) private readonly frameExtractionQueue: Queue,
  ) {}

  list(companyId: string, user?: { role?: string; warehouseId?: string | null }) {
    return this.prisma.evidence.findMany({
      where: { companyId, ...warehouseScope(user || {}, {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
      include: {
        order: { select: { id: true, marketplaceOrderId: true, status: true } },
        recording: true,
        frames: { orderBy: { sequence: 'asc' } },
      } as any,
    });
    if (!e) throw new NotFoundException('Evidence not found');
    assertWarehouseAccess(user || {}, (e as any).recording?.warehouseId);

    let downloadUrl: string | null = null;
    const key = (e as any).storageKey as string | undefined;
    if (key && typeof (this.storage as any).presignGet === 'function') {
      try {
        const signed = await (this.storage as any).presignGet(key);
        downloadUrl = signed?.url ?? null;
      } catch (_) {}
    }

    const frames = (e as any).frames || [];
    const frameCount = (e as any).frameCount || frames.length || 0;

    return {
      ...e,
      frameCount,
      frames: frames.map((f: any) => ({
        index: f.sequence,
        label: f.label ?? `Frame ${f.sequence}`,
        type: f.label?.includes('keyframe') ? 'keyframe' : 'sample',
        b2Key: f.b2Key,
        timestampMs: f.timestampMs,
        checksum: f.checksum,
      })),
      downloadUrl,
      thumbnailUrl: (e as any).thumbnailKey ?? null,
      processingStatus: 'ready',
    };
  }

  async getDownload(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!e) throw new NotFoundException('Evidence not found');
    assertWarehouseAccess(user || {}, (e as any).recording?.warehouseId);

    const key = (e as any).storageKey as string | undefined;
    if (!key) {
      return {
        evidenceId: id,
        url: null,
        message: 'No storageKey on evidence yet',
      };
    }

    try {
      if (typeof (this.storage as any).presignGet === 'function') {
        const signed = await (this.storage as any).presignGet(key);
        return {
          evidenceId: id,
          key,
          url: signed?.url ?? null,
          expiresIn: signed?.expiresIn,
        };
      }
    } catch (err: any) {
      return {
        evidenceId: id,
        key,
        url: null,
        message: err?.message || 'presign failed',
      };
    }

    return {
      evidenceId: id,
      key,
      url: null,
      message: 'presignGet not available',
    };
  }

  /**
   * Queue frame extraction job for real FFmpeg processing
   */
  async queueFrameExtraction(
    companyId: string,
    id: string,
    videoPath: string,
    options?: { maxFrames?: number; thumbnailSize?: string },
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!e) throw new NotFoundException('Evidence not found');
    assertWarehouseAccess(user || {}, (e as any).recording?.warehouseId);

    const jobData: FrameExtractionJobData = {
      evidenceId: id,
      companyId,
      videoPath,
      options: {
        maxFrames: options?.maxFrames ?? 50,
        thumbnailSize: options?.thumbnailSize ?? '320x240',
      },
    };

    await this.frameExtractionQueue.add('extract-frames', jobData, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
      removeOnComplete: 100,
      removeOnFail: 50,
    });

    // Update evidence status to pending
    await this.prisma.evidence.update({
      where: { id },
      data: {
        status: 'pending',
      },
    });

    return { queued: true, jobId: 'queued' };
  }

  /**
   * Local/dev helper: mark evidence as processed from a local video path.
   * Real FFmpeg extract runs on worker when ffmpeg + B2 object exist.
   */
  async processLocalVideo(
    companyId: string,
    id: string,
    videoPath?: string,
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!e) throw new NotFoundException('Evidence not found');
    assertWarehouseAccess(user || {}, (e as any).recording?.warehouseId);
    if (!videoPath || typeof videoPath !== 'string') {
      throw new BadRequestException('videoPath is required');
    }

    // Queue real frame extraction
    await this.queueFrameExtraction(companyId, id, videoPath, {
      maxFrames: 50,
      thumbnailSize: '320x240',
    }, user);

    return {
      ...e,
      status: 'pending',
      frameCount: 0,
      processingStatus: 'queued_for_extraction',
    };
  }
}