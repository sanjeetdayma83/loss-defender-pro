import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class EvidenceService {
  private readonly logger = new Logger(EvidenceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async list(companyId: string) {
    const rows = await this.prisma.evidence.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((r) => this.serialize(r));
  }

  private serialize(row: any) {
    const out: any = { ...row };
    for (const k of Object.keys(out)) {
      if (typeof out[k] === 'bigint') out[k] = out[k].toString();
    }
    return out;
  }

  private async resolvePackKey(
    evidenceId: string,
    recordingId: string | null | undefined,
    rawKey: string | null | undefined,
  ): Promise<string | null> {
    let packKey = (rawKey || '').trim();
    if (packKey.includes(' ')) {
      packKey =
        packKey.split(/\s+/).find((k) => k.endsWith('.webm')) ||
        packKey.split(/\s+/)[0];
    }
    const needsFallback =
      !packKey ||
      packKey.endsWith('pack.json') ||
      packKey.includes('/pack.json');

    if (needsFallback && recordingId) {
      try {
        const seg = await this.prisma.recordingSegment.findFirst({
          where: { recordingId },
          orderBy: { sequence: 'asc' },
        });
        const b2 = (seg as any)?.b2Key as string | undefined;
        if (b2) {
          packKey = b2;
          try {
            await this.prisma.evidence.update({
              where: { id: evidenceId },
              data: { packKey, status: 'ready' } as any,
            });
          } catch (_) {}
        }
      } catch (e: any) {
        this.logger.warn(`segment fallback: ${e?.message}`);
      }
    }
    return packKey || null;
  }

  async getOne(companyId: string, id: string) {
    const row = await this.prisma.evidence.findFirst({
      where: { id, companyId },
    });
    if (!row) throw new NotFoundException('Evidence not found');

    const packKey = await this.resolvePackKey(
      id,
      (row as any).recordingId,
      (row as any).packKey,
    );

    const thumbKey = (row as any).thumbnailKey as string | null | undefined;
    let packDownloadUrl: string | null = null;
    let thumbnailUrl: string | null = null;

    if (packKey) {
      try {
        const p = await this.storage.presignGet(packKey, 900);
        packDownloadUrl = (p as any)?.downloadUrl ?? null;
      } catch (_) {}
    }
    if (thumbKey) {
      try {
        const t = await this.storage.presignGet(thumbKey, 900);
        thumbnailUrl = (t as any)?.downloadUrl ?? null;
      } catch (_) {}
    }

    let frames: any[] = [];
    try {
      frames = await (this.prisma as any).evidenceFrame.findMany({
        where: { evidenceId: id },
        orderBy: { sequence: 'asc' },
      });
    } catch {
      frames = [];
    }

    const framesWithUrls: any[] = [];
    for (const f of frames) {
      let downloadUrl: string | null = null;
      if (f.b2Key) {
        try {
          const g = await this.storage.presignGet(f.b2Key, 900);
          downloadUrl = (g as any)?.downloadUrl ?? null;
        } catch (_) {}
      }
      framesWithUrls.push({ ...f, downloadUrl });
    }

    let segmentDownloadUrl: string | null = packDownloadUrl;
    let segmentKey: string | null = packKey;
    if ((row as any).recordingId) {
      try {
        const seg = await this.prisma.recordingSegment.findFirst({
          where: { recordingId: (row as any).recordingId },
          orderBy: { sequence: 'asc' },
        });
        if ((seg as any)?.b2Key) {
          segmentKey = (seg as any).b2Key as string;
          const g = await this.storage.presignGet(segmentKey, 900);
          segmentDownloadUrl = (g as any)?.downloadUrl ?? segmentDownloadUrl;
        }
      } catch (_) {}
    }

    return {
      ...this.serialize(row),
      packKey,
      packDownloadUrl: packDownloadUrl || segmentDownloadUrl,
      thumbnailUrl,
      segmentKey,
      segmentDownloadUrl,
      frames: framesWithUrls,
      expiresInSec: 900,
    };
  }

  /** Controller calls getDownload — alias */
  async getDownload(companyId: string, id: string) {
    return this.getDownloadUrl(companyId, id);
  }

  async getDownloadUrl(companyId: string, id: string) {
    const detail = await this.getOne(companyId, id);
    return {
      evidenceId: id,
      packKey: (detail as any).packKey ?? null,
      packDownloadUrl: (detail as any).packDownloadUrl ?? null,
      segmentDownloadUrl: (detail as any).segmentDownloadUrl ?? null,
      downloadUrl:
        (detail as any).packDownloadUrl ||
        (detail as any).segmentDownloadUrl ||
        null,
    };
  }

  /** Controller processLocalVideo — stub until FFmpeg wired */
  async processLocalVideo(
    companyId: string,
    evidenceId: string,
    videoPath: string,
  ) {
    const row = await this.prisma.evidence.findFirst({
      where: { id: evidenceId, companyId },
    });
    if (!row) throw new NotFoundException('Evidence not found');
    this.logger.warn(
      `processLocalVideo stub path=${videoPath} evidence=${evidenceId}`,
    );
    return {
      evidenceId,
      status: 'queued',
      message:
        'Local video processing stub — set FFMPEG_PATH and restore extractFrames for production',
      videoPath,
    };
  }
}
