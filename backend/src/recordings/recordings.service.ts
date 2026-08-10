import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { createHash } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class RecordingsService {
  constructor(private readonly prisma: PrismaService, private readonly storage: StorageService, @InjectQueue('evidence') private readonly evidenceQueue: Queue) {}

  list(companyId: string) { return this.prisma.recording.findMany({ where: { companyId }, orderBy: { createdAt: 'desc' }, take: 100, include: { segments: { orderBy: { sequence: 'asc' } }, evidence: true } }); }

  async getOne(companyId: string, id: string) {
    const rec = await this.prisma.recording.findFirst({ where: { id, companyId }, include: { segments: { orderBy: { sequence: 'asc' } }, evidence: true } });
    if (!rec) throw new NotFoundException('Recording not found');
    return rec;
  }

  async start(companyId: string, actorId: string, orderId: string, warehouseId: string) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId, companyId } });
    if (!order) throw new NotFoundException('Order not found');
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new BadRequestException('Warehouse not in your company');
    const rec = await this.prisma.recording.create({ data: { companyId, orderId, warehouseId, operatorId: actorId, status: 'started', startedAt: new Date(), segmentCount: 0 } });
    await this.prisma.order.update({ where: { id: orderId }, data: { status: 'recording' as any } });
    return rec;
  }

  async stop(companyId: string, recordingId: string, _actorId?: string, durationSec?: number, _segmentCount?: number) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId }, include: { segments: true } });
    if (!rec) throw new NotFoundException('Recording not found');
    if (!rec.segments.length) throw new BadRequestException('Cannot finalize recording without an uploaded segment');
    const ordered = [...rec.segments].sort((a, b) => a.sequence - b.sequence);
    const aggregate = createHash('sha256');
    let totalBytes = 0;
    for (const s of ordered) { totalBytes += Number(s.sizeBytes); aggregate.update(`${s.sequence}:${s.b2Key}:${s.sizeBytes}:${s.checksum || ''};`); }
    const updated = await this.prisma.recording.update({ where: { id: recordingId }, data: { status: 'processing', completedAt: new Date(), durationSec, segmentCount: ordered.length, totalBytes: BigInt(totalBytes), checksum: aggregate.digest('hex'), b2Prefix: `${companyId}/recordings/${recordingId}/` } });
    const evidence = await this.prisma.evidence.upsert({ where: { recordingId }, create: { companyId, orderId: rec.orderId, recordingId, status: 'pending', frameCount: 0 }, update: { status: 'pending', frameCount: 0 } });
    await this.evidenceQueue.add('process-recording', { companyId, recordingId, evidenceId: evidence.id }, { jobId: `recording:${recordingId}`, attempts: 5, backoff: { type: 'exponential', delay: 5000 }, removeOnComplete: 1000, removeOnFail: 5000 });
    return { recording: updated, evidence, queued: true };
  }

  async presignSegment(companyId: string, recordingId: string, segmentIndex: number, contentType = 'video/webm') {
    if (!Number.isInteger(segmentIndex) || segmentIndex < 0) throw new BadRequestException('Invalid segment index');
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    if (!this.storage.isConfigured()) throw new BadRequestException('B2 storage is not configured');
    const key = this.storage.recordingSegmentKey(companyId, recordingId, segmentIndex);
    return { ...(await this.storage.presignPut(key, contentType)), segmentIndex, recordingId };
  }

  async registerSegment(companyId: string, recordingId: string, sequence: number, b2Key: string, sizeBytes?: number, durationSec?: number) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    if (!this.storage.isConfigured()) throw new BadRequestException('B2 storage is not configured');
    if (!b2Key.startsWith(`${companyId}/recordings/${recordingId}/`)) throw new BadRequestException('Segment key does not belong to this recording');
    const body = await this.storage.downloadBuffer(b2Key);
    if (sizeBytes != null && sizeBytes !== body.length) throw new BadRequestException('Segment size mismatch');
    const checksum = createHash('sha256').update(body).digest('hex');
    return this.prisma.recordingSegment.upsert({
      where: { recordingId_sequence: { recordingId, sequence } },
      create: { recordingId, companyId, sequence, b2Key, sizeBytes: BigInt(body.length), durationSec, checksum },
      update: { b2Key, sizeBytes: BigInt(body.length), durationSec, checksum, uploadedAt: new Date() },
    });
  }
}
