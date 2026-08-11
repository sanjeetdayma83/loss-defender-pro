import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

/** Downloads segment (presign) metadata and seeds frame placeholders.
 *  Full FFmpeg extract when FFMPEG_PATH set + temp download implemented. */
@Injectable()
export class EvidenceFramesService {
  private readonly log = new Logger(EvidenceFramesService.name);
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async ensurePlaceholders(companyId: string, evidenceId: string, recordingId: string) {
    const segs = await this.prisma.recordingSegment.findMany({
      where: { recordingId },
      orderBy: { sequence: 'asc' },
      take: 1,
    });
    const key = (segs[0] as any)?.b2Key as string | undefined;
    const count = 4;
    for (let i = 0; i < count; i++) {
      try {
        await (this.prisma as any).evidenceFrame.upsert({
          where: { evidenceId_sequence: { evidenceId, sequence: i } },
          create: {
            evidenceId,
            sequence: i,
            b2Key: key ? `${key}.frame_${i}.jpg` : null,
            label: `frame_${i}`,
          },
          update: {},
        });
      } catch {
        // model may differ — skip
      }
    }
    await this.prisma.evidence.update({
      where: { id: evidenceId },
      data: { frameCount: count } as any,
    }).catch(() => null);
    this.log.log(`frames placeholders evidence=${evidenceId} source=${key} ffmpeg=${process.env.FFMPEG_PATH || 'off'}`);
    return { evidenceId, frameCount: count, sourceKey: key, ffmpeg: !!process.env.FFMPEG_PATH };
  }
}
