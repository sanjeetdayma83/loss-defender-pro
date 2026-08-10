import { Injectable, NotFoundException } from '@nestjs/common';
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
    });
    if (!e) throw new NotFoundException('Evidence not found');

    let downloadUrl: string | null = null;
    const packKey = (e as any).packKey as string | undefined;
    if (packKey) {
      try {
        const signed = await this.storage.presignGet(packKey);
        downloadUrl = (signed as any)?.downloadUrl ?? null;
      } catch (_) {}
    }

    const meta = ((e as any).metadata as any) || {};
    const frames =
      meta.frames ||
      Array.from({ length: (e as any).frameCount || 0 }, (_, i) => ({
        index: i,
        type: 'placeholder',
        label: `Frame ${i + 1}`,
        status: 'pending_extract',
      }));

    return {
      ...e,
      downloadUrl,
      frames,
      thumbnailUrl: meta.thumbnailUrl ?? null,
      processingStatus: meta.processingStatus ?? (e as any).status,
    };
  }

  async getDownloadUrl(companyId: string, id: string) {
    const row = await this.prisma.evidence.findFirst({ where: { id, companyId } });
    if (!row) throw new NotFoundException('Evidence not found');
    const packKey = (row as any).packKey;
    if (!packKey) {
      return { configured: false, downloadUrl: null, message: 'No packKey yet' };
    }
    const signed = await this.storage.presignGet(packKey);
    return { ...signed, evidenceId: id };
  }

  async createFromRecording(
    companyId: string,
    orderId: string,
    recordingId: string,
    segmentCount = 1,
  ) {
    const frameCount = Math.max(segmentCount, 1) * 3;
    const frames = Array.from({ length: frameCount }, (_, i) => ({
      index: i,
      type: i % 3 === 0 ? 'keyframe' : 'sample',
      label: `Frame ${i + 1}`,
      status: 'pending_extract',
    }));

    let evidence = await this.prisma.evidence.create({
      data: {
        companyId,
        orderId,
        recordingId,
        status: 'pending',
        frameCount,
        metadata: {
          frames,
          processingStatus: 'frames_queued',
          queuedAt: new Date().toISOString(),
        },
      } as any,
    });

    const packKey = this.storage.evidencePackKey(companyId, evidence.id);
    const newStatus = this.storage.isConfigured() ? 'ready' : 'pending';

    evidence = await this.prisma.evidence.update({
      where: { id: evidence.id },
      data: {
        packKey,
        status: newStatus,
        metadata: {
          frames,
          processingStatus: this.storage.isConfigured() ? 'ready' : 'frames_queued',
          packKey,
        },
      } as any,
    });

    return evidence;
  }
}
