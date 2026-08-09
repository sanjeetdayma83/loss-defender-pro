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
      include: {
        evidence: true,
        segments: { orderBy: { sequence: 'asc' } },
      },
    });
  }

  async start(
    companyId: string,
    operatorId: string,
    orderId: string,
    warehouseId: string,
  ) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, companyId },
    });
    if (!order) throw new NotFoundException('Order not found');
    const wh = await this.prisma.warehouse.findFirst({
      where: { id: warehouseId, companyId },
    });
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
      delete data.operatorId;
      data.userId = operatorId;
      try {
        rec = await this.prisma.recording.create({ data });
      } catch (e2: any) {
        throw new BadRequestException(
          `Recording create failed: ${e2?.message || e1?.message}`,
        );
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

  async addSegment(
    companyId: string,
    recordingId: string,
    dto: {
      sequence: number;
      b2Key: string;
      sizeBytes: number;
      durationSec?: number;
      checksum?: string;
    },
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    if (!['started', 'paused', 'completed'].includes(String(rec.status))) {
      throw new BadRequestException(`Cannot add segment in status ${rec.status}`);
    }

    const segment = await this.prisma.recordingSegment.upsert({
      where: {
        recordingId_sequence: {
          recordingId,
          sequence: dto.sequence,
        },
      },
      create: {
        recordingId,
        companyId,
        sequence: dto.sequence,
        b2Key: dto.b2Key,
        sizeBytes: BigInt(Math.max(0, Math.floor(dto.sizeBytes || 0))),
        durationSec: dto.durationSec,
        checksum: dto.checksum,
      },
      update: {
        b2Key: dto.b2Key,
        sizeBytes: BigInt(Math.max(0, Math.floor(dto.sizeBytes || 0))),
        durationSec: dto.durationSec,
        checksum: dto.checksum,
        uploadedAt: new Date(),
      },
    });

    const count = await this.prisma.recordingSegment.count({
      where: { recordingId },
    });
    await this.prisma.recording.update({
      where: { id: recordingId },
      data: { segmentCount: count },
    });

    return segment;
  }

  async stop(
    companyId: string,
    recordingId: string,
    durationSec?: number,
    segmentCount?: number,
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId },
      include: { segments: { orderBy: { sequence: 'asc' } } },
    });
    if (!rec) throw new NotFoundException('Recording not found');

    const segs = (rec as any).segments as any[];
    const actualCount = segs?.length ?? segmentCount ?? 0;

    const data: any = {
      status: 'completed',
      completedAt: new Date(),
      segmentCount: actualCount,
    };
    if (durationSec != null) data.durationSec = durationSec;

    let updated;
    try {
      updated = await this.prisma.recording.update({
        where: { id: recordingId },
        data,
      });
    } catch {
      delete data.completedAt;
      data.stoppedAt = new Date();
      updated = await this.prisma.recording.update({
        where: { id: recordingId },
        data,
      });
    }

    // Evidence: real segment keys → EvidenceFrame rows
    let evidence: any = null;
    try {
      evidence = await this.prisma.evidence.upsert({
        where: { recordingId: rec.id },
        create: {
          companyId,
          orderId: rec.orderId,
          recordingId: rec.id,
          status: actualCount > 0 ? 'ready' : 'pending',
          frameCount: actualCount,
          packKey: segs?.[0]?.b2Key ?? null,
        },
        update: {
          status: actualCount > 0 ? 'ready' : 'pending',
          frameCount: actualCount,
          packKey: segs?.[0]?.b2Key ?? null,
        },
      });

      // Sync frames from uploaded segments
      for (const seg of segs || []) {
        const existing = await this.prisma.evidenceFrame.findFirst({
          where: {
            evidenceId: evidence.id,
            sequence: seg.sequence,
          },
        });
        if (!existing) {
          await this.prisma.evidenceFrame.create({
            data: {
              evidenceId: evidence.id,
              companyId,
              sequence: seg.sequence,
              b2Key: seg.b2Key,
              timestampMs: seg.durationSec != null ? seg.durationSec * 1000 : null,
              label: `segment_${seg.sequence}`,
              checksum: seg.checksum ?? null,
            },
          });
        }
      }
    } catch (e: any) {
      console.error('evidence create', e?.message);
    }

    try {
      await this.prisma.order.update({
        where: { id: rec.orderId },
        data: { status: 'evidence_ready' as any },
      });
    } catch (_) {}

    return { recording: updated, evidence, segmentCount: actualCount };
  }

  async presignSegment(
    companyId: string,
    recordingId: string,
    segmentIndex: number,
    contentType = 'video/webm',
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    const key = `${companyId}/recordings/${recordingId}/seg_${segmentIndex}.webm`;
    const signed = await this.storage.presignPut(key, contentType);
    return { ...signed, segmentIndex, recordingId, key };
  }
}