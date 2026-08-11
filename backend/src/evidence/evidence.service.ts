import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class EvidenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  list(companyId: string) {
    return this.prisma.evidence.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId },
      include: {
        order: { select: { id: true, marketplaceOrderId: true, status: true } },
        recording: true,
      } as any,
    });
    if (!e) throw new NotFoundException('Evidence not found');

    let downloadUrl: string | null = null;
    const key = (e as any).storageKey as string | undefined;
    if (key && typeof (this.storage as any).presignGet === 'function') {
      try {
        const signed = await (this.storage as any).presignGet(key);
        downloadUrl = signed?.url ?? null;
      } catch (_) {}
    }

    const meta = ((e as any).metadata as any) || {};
    let frames = Array.isArray(meta.frames) ? meta.frames : [];
    const frameCount = Number((e as any).frameCount || frames.length || 0);
    if ((!frames || frames.length === 0) && frameCount > 0) {
      frames = Array.from({ length: frameCount }, (_, i) => ({
        index: i,
        label: `Frame ${i + 1}`,
        status: 'pending_extract',
        type: i % 3 === 0 ? 'keyframe' : 'sample',
      }));
    }

    return {
      ...e,
      frameCount,
      frames,
      downloadUrl,
      thumbnailUrl: meta.thumbnailUrl ?? null,
      processingStatus: meta.processingStatus ?? (e as any).status,
    };
  }

  async getDownload(companyId: string, id: string) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId },
    });
    if (!e) throw new NotFoundException('Evidence not found');

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
   * Local/dev helper: mark evidence as processed from a local video path.
   * Real FFmpeg extract runs on worker when ffmpeg + B2 object exist.
   */
  async processLocalVideo(
    companyId: string,
    id: string,
    videoPath?: string,
  ) {
    const e = await this.prisma.evidence.findFirst({
      where: { id, companyId },
    });
    if (!e) throw new NotFoundException('Evidence not found');
    if (!videoPath || typeof videoPath !== 'string') {
      throw new BadRequestException('videoPath is required');
    }

    const frameCount = Math.max(Number((e as any).frameCount) || 3, 3);
    const frames = Array.from({ length: frameCount }, (_, i) => ({
      index: i,
      label: `Frame ${i + 1}`,
      status: 'extracted_stub',
      type: i % 3 === 0 ? 'keyframe' : 'sample',
      sourcePath: videoPath,
    }));

    const meta = {
      ...(((e as any).metadata as any) || {}),
      frames,
      processingStatus: 'processed_local_stub',
      localVideoPath: videoPath,
      processedAt: new Date().toISOString(),
      note: 'Stub without ffmpeg — install ffmpeg on worker for real frames',
    };

    const updated = await this.prisma.evidence.update({
      where: { id },
      data: {
        frameCount,
        metadata: meta,
        status: 'ready',
      } as any,
    });

    return {
      ...updated,
      frames,
      frameCount,
      processingStatus: meta.processingStatus,
    };
  }
}
