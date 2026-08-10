import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class RecordingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  list(companyId: string) {
    return this.prisma.recording.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string) {
    const rec = await this.prisma.recording.findFirst({ where: { id, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    return rec;
  }

  async start(companyId: string, actorId: string, orderId: string, warehouseId: string) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId, companyId } });
    if (!order) throw new NotFoundException('Order not found');
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new BadRequestException('Warehouse not in your company');

    const rec = await this.prisma.recording.create({
      data: {
        companyId,
        orderId,
        warehouseId,
        operatorId: actorId,
        status: 'started',
        startedAt: new Date(),
        segmentCount: 0,
      } as any,
    });

    try {
      await this.prisma.order.update({
        where: { id: orderId },
        data: { status: 'recording' as any },
      });
    } catch (_) {}

    return rec;
  }

  async stop(
    companyId: string,
    recordingId: string,
    actorIdOrDuration?: string | number,
    durationSec?: number,
    segmentCount?: number,
  ) {
    // Support both call styles: stop(companyId, id, actorId, duration, segments)
    // and stop(companyId, id, duration, segments)
    let actorId: string | null = null;
    if (typeof actorIdOrDuration === 'string') {
      actorId = actorIdOrDuration;
    } else if (typeof actorIdOrDuration === 'number') {
      durationSec = actorIdOrDuration;
    }

    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');

    const data: any = {
      status: 'completed',
      completedAt: new Date(),
    };
    if (durationSec != null) data.durationSec = durationSec;
    if (segmentCount != null) data.segmentCount = segmentCount;

    const updated = await this.prisma.recording.update({ where: { id: recordingId }, data });

    let evidence: any = null;
    try {
      evidence = await this.prisma.evidence.create({
        data: {
          companyId,
          orderId: rec.orderId,
          recordingId: rec.id,
          status: 'pending',
          frameCount: segmentCount ?? 1,
        } as any,
      });
      const packKey = this.storage.evidencePackKey
        ? this.storage.evidencePackKey(companyId, evidence.id)
        : `${companyId}/evidence/${evidence.id}/pack.json`;
      evidence = await this.prisma.evidence.update({
        where: { id: evidence.id },
        data: {
          packKey,
          status: this.storage.isConfigured() ? 'ready' : 'pending',
        } as any,
      });
    } catch (e: any) {
      console.error('evidence create', e?.message);
    }

    try {
      await this.prisma.order.update({
        where: { id: rec.orderId },
        data: { status: 'evidence_ready' as any },
      });
    } catch (_) {}

    return { recording: updated, evidence };
  }

  async presignSegment(
    companyId: string,
    recordingId: string,
    segmentIndex: number,
    contentType = 'video/webm',
  ) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    const key = this.storage.recordingSegmentKey
      ? this.storage.recordingSegmentKey(companyId, recordingId, segmentIndex)
      : `${companyId}/recordings/${recordingId}/seg_${segmentIndex}.webm`;
    return {
      ...(await this.storage.presignPut(key, contentType)),
      segmentIndex,
      recordingId,
    };
  }
}
