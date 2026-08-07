import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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

  async start(companyId: string, operatorId: string, orderId: string, warehouseId: string) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId, companyId } });
    if (!order) throw new NotFoundException('Order not found');
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new BadRequestException('Warehouse not in company');

    const data: any = {
      companyId,
      orderId,
      warehouseId,
      operatorId,
      status: 'started',
      startedAt: new Date(),
    };

    let rec;
    try {
      rec = await this.prisma.recording.create({ data });
    } catch (e1: any) {
      // fallback field names
      delete data.operatorId;
      data.userId = operatorId;
      try {
        rec = await this.prisma.recording.create({ data });
      } catch (e2: any) {
        throw new BadRequestException(`Recording create failed: ${e2?.message || e1?.message}`);
      }
    }

    try {
      await this.prisma.order.update({
        where: { id: orderId },
        data: { status: 'recording' as any },
      });
    } catch (_) {}

    return rec;
  }

  async stop(companyId: string, recordingId: string, durationSec?: number, segmentCount?: number) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');

    const data: any = { status: 'completed', completedAt: new Date() };
    if (durationSec != null) data.durationSec = durationSec;
    if (segmentCount != null) data.segmentCount = segmentCount;

    let updated;
    try {
      updated = await this.prisma.recording.update({ where: { id: recordingId }, data });
    } catch {
      delete data.completedAt;
      data.stoppedAt = new Date();
      updated = await this.prisma.recording.update({ where: { id: recordingId }, data });
    }

    let evidence: any = null;
    try {
      evidence = await this.prisma.evidence.create({
        data: {
          companyId,
          orderId: rec.orderId,
          recordingId: rec.id,
          status: 'ready',
          frameCount: segmentCount ?? 1,
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

  async presignSegment(companyId: string, recordingId: string, segmentIndex: number, contentType = 'video/webm') {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    const key = `${companyId}/recordings/${recordingId}/seg_${segmentIndex}.webm`;
    const signed = await this.storage.presignPut(key, contentType);
    return { ...signed, segmentIndex, recordingId, key };
  }
}