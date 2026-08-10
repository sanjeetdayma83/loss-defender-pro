import { Injectable, Logger, NotFoundException, BadRequestException, InternalServerErrorException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { createHash } from 'crypto';
import { execFile } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs'; import * as path from 'path'; import * as os from 'os';
const execFileAsync = promisify(execFile);
@Injectable()
export class EvidenceService {
  private readonly logger = new Logger(EvidenceService.name); private readonly ffmpegBin = process.env.FFMPEG_PATH || 'ffmpeg';
  constructor(private readonly prisma: PrismaService, private readonly storage: StorageService) {}
  list(companyId: string) { return this.prisma.evidence.findMany({ where: { companyId }, orderBy: { createdAt: 'desc' }, take: 100 }); }
  async getOne(companyId: string, id: string) { const row = await this.prisma.evidence.findFirst({ where: { id, companyId }, include: { frames: true } }); if (!row) throw new NotFoundException('Evidence not found'); return row; }
  async processRecordingEvidence(companyId: string, recordingId: string, evidenceId: string, maxFramesPerSegment = 8) {
    const recording = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId }, include: { segments: { orderBy: { sequence: 'asc' } } } });
    const evidence = await this.prisma.evidence.findFirst({ where: { id: evidenceId, companyId } });
    if (!recording || !evidence) throw new NotFoundException('Recording/evidence not found');
    if (!recording.segments.length) throw new BadRequestException('No recording segments available');
    if (!this.storage.isConfigured()) throw new BadRequestException('B2 storage is not configured');
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ldp-evidence-')); let globalFrame = 0; const manifest: any[] = [];
    try {
      await this.prisma.evidence.update({ where: { id: evidenceId }, data: { status: 'pending', frameCount: 0 } });
      for (const segment of recording.segments) {
        const video = await this.storage.downloadBuffer(segment.b2Key);
        const checksum = createHash('sha256').update(video).digest('hex');
        if (segment.checksum && checksum !== segment.checksum) throw new BadRequestException(`Checksum mismatch for segment ${segment.sequence}`);
        const videoPath = path.join(tmpDir, `segment_${segment.sequence}.webm`); fs.writeFileSync(videoPath, video);
        const framePattern = path.join(tmpDir, `s${segment.sequence}_frame_%03d.jpg`);
        await execFileAsync(this.ffmpegBin, ['-y', '-i', videoPath, '-vf', 'fps=1/2', '-frames:v', String(maxFramesPerSegment), framePattern], { timeout: 120000, windowsHide: true });
        const frames = fs.readdirSync(tmpDir).filter((f) => f.startsWith(`s${segment.sequence}_frame_`) && f.endsWith('.jpg')).sort();
        for (const frameFile of frames) {
          const frame = fs.readFileSync(path.join(tmpDir, frameFile)); const frameChecksum = createHash('sha256').update(frame).digest('hex');
          const key = `${companyId}/evidence/${evidenceId}/frames/${String(globalFrame).padStart(6, '0')}.jpg`;
          await this.storage.uploadBuffer(key, frame, 'image/jpeg');
          await this.prisma.evidenceFrame.upsert({ where: { evidenceId_sequence: { evidenceId, sequence: globalFrame } }, create: { evidenceId, companyId, sequence: globalFrame, b2Key: key, checksum: frameChecksum }, update: { b2Key: key, checksum: frameChecksum } });
          manifest.push({ sequence: globalFrame, segment: segment.sequence, b2Key: key, checksum: frameChecksum }); globalFrame++;
        }
      }
      if (!globalFrame) throw new BadRequestException('FFmpeg produced no evidence frames');
      const pack = { version: 1, evidenceId, companyId, recordingId, orderId: recording.orderId, generatedAt: new Date().toISOString(), segments: recording.segments.map((s) => ({ sequence: s.sequence, b2Key: s.b2Key, sizeBytes: Number(s.sizeBytes), checksum: s.checksum })), frames: manifest };
      const packBuffer = Buffer.from(JSON.stringify(pack, null, 2)); const packChecksum = createHash('sha256').update(packBuffer).digest('hex'); const packKey = `${companyId}/evidence/${evidenceId}/pack.json`;
      await this.storage.uploadBuffer(packKey, packBuffer, 'application/json');
      const updated = await this.prisma.evidence.update({ where: { id: evidenceId }, data: { frameCount: globalFrame, packKey, checksum: packChecksum, status: 'ready' } });
      await this.prisma.recording.update({ where: { id: recordingId }, data: { status: 'processed' } });
      await this.prisma.order.update({ where: { id: recording.orderId }, data: { status: 'evidence_ready' as any } });
      return updated;
    } catch (e: any) {
      this.logger.error(`Evidence processing failed: ${e?.message || e}`); await this.prisma.evidence.update({ where: { id: evidenceId }, data: { status: 'failed' } }).catch(() => undefined); await this.prisma.recording.update({ where: { id: recordingId }, data: { status: 'failed' } }).catch(() => undefined); throw new InternalServerErrorException(e?.message || 'Evidence processing failed');
    } finally { fs.rmSync(tmpDir, { recursive: true, force: true }); }
  }
  async processLocalVideo(companyId: string, evidenceId: string, _videoPath: string) { const evidence = await this.prisma.evidence.findFirst({ where: { id: evidenceId, companyId } }); if (!evidence) throw new NotFoundException('Evidence not found'); throw new BadRequestException('Local filesystem extraction is disabled; upload/register a B2 recording segment instead'); }
}
