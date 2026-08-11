import { Injectable, Logger, NotFoundException, InternalServerErrorException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { execFile } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

const execFileAsync = promisify(execFile);

@Injectable()
export class EvidenceService {
  async list(companyId: string) {
    return this.prisma.evidence.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }
  private readonly logger = new Logger(EvidenceService.name);
  private readonly ffmpegBin: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {
    this.ffmpegBin = process.env.FFMPEG_PATH || 'ffmpeg';
    this.logger.log(`FFmpeg binary: ${this.ffmpegBin}`);
  }


  async getOne(companyId: string, id: string) {
    const row = await this.prisma.evidence.findFirst({ where: { id, companyId } });
    if (!row) throw new NotFoundException('Evidence not found');

    let packKey = (row as any).packKey as string | null | undefined;
    if (!packKey && (row as any).recordingId) {
      try {
        const seg = await this.prisma.recordingSegment.findFirst({
          where: { recordingId: (row as any).recordingId },
          orderBy: { sequence: 'asc' },
        });
        packKey = (seg as any)?.b2Key ?? null;
        if (packKey) {
          await this.prisma.evidence.update({
            where: { id },
            data: { packKey, status: 'ready' } as any,
          });
        }
      } catch (_) {}
    }
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

    return {
      ...row,
      packDownloadUrl,
      thumbnailUrl,
      frames: framesWithUrls,
      expiresInSec: 900,
    };
  }

  async processLocalVideo(companyId: string, evidenceId: string, videoPath: string) {
    return this.extractFramesFromFile(companyId, evidenceId, videoPath);
  }

  async extractFramesFromFile(
    companyId: string,
    evidenceId: string,
    videoPath: string,
    maxFrames = 8,
  ) {
    const evidence = await this.prisma.evidence.findFirst({
      where: { id: evidenceId, companyId },
    });
    if (!evidence) throw new NotFoundException('Evidence not found');

    const resolved = path.resolve(videoPath);
    if (!fs.existsSync(resolved)) {
      throw new NotFoundException(`Video not found: ${resolved}`);
    }

    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ldp-frames-'));
    const pattern = path.join(tmpDir, 'frame_%03d.jpg');

    try {
      await execFileAsync(
        this.ffmpegBin,
        ['-y', '-i', resolved, '-vf', 'fps=1/2', '-frames:v', String(maxFrames), pattern],
        { timeout: 120000, windowsHide: true },
      );

      const frames = fs.readdirSync(tmpDir).filter((f) => f.endsWith('.jpg')).sort();
      const frameKeys: string[] = [];
      const uploaded: string[] = [];

      for (const f of frames) {
        const key = `${companyId}/evidence/${evidenceId}/frames/${f}`;
        frameKeys.push(key);
        try {
          if (this.storage.isConfigured && this.storage.isConfigured()) {
            const buf = fs.readFileSync(path.join(tmpDir, f));
            const up = await (this.storage as any).uploadBuffer(key, buf, 'image/jpeg');
            if (up?.configured) uploaded.push(key);
          }
        } catch (upErr: any) {
          this.logger.warn(`Frame upload ${f}: ${upErr?.message}`);
        }
      }

      const packKey =
        (evidence as any).packKey ||
        `${companyId}/evidence/${evidenceId}/pack.json`;

      let updated;
      try {
        updated = await this.prisma.evidence.update({
          where: { id: evidenceId },
          data: {
            frameCount: frames.length,
            status: frames.length ? 'ready' : 'pending',
            packKey,
          } as any,
        });
      } catch {
        updated = await this.prisma.evidence.update({
          where: { id: evidenceId },
          data: { frameCount: frames.length, status: 'ready' } as any,
        });
      }

      return {
        evidence: updated,
        frameCount: frames.length,
        tmpDir,
        frameFiles: frames,
        frameKeys,
        uploaded,
        ffmpeg: this.ffmpegBin,
      };
    } catch (e: any) {
      this.logger.error(`FFmpeg failed: ${e?.message}`);
      throw new InternalServerErrorException(e?.message || 'FFmpeg frame extraction failed');
    }
  }

  async processFromB2Key(companyId: string, evidenceId: string, b2Key: string) {
    const buf = await this.storage.getObjectBuffer(b2Key);
    if (!buf || !buf.length) {
      throw new NotFoundException(`B2 object missing or empty: ${b2Key}`);
    }
    const tmp = path.join(os.tmpdir(), `ldp-vid-${evidenceId}.webm`);
    fs.writeFileSync(tmp, buf);
    try {
      return await this.extractFramesFromFile(companyId, evidenceId, tmp);
    } finally {
      try { fs.unlinkSync(tmp); } catch (_) {}
    }
  }

  async getDownload(companyId: string, id: string) {
    const detail = await this.getOne(companyId, id);
    return {
      evidenceId: id,
      packKey: (detail as any).packKey ?? null,
      packDownloadUrl: (detail as any).packDownloadUrl ?? null,
      thumbnailUrl: (detail as any).thumbnailUrl ?? null,
      frames: (detail as any).frames ?? [],
      expiresInSec: 900,
    };
  }
}