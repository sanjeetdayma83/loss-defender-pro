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
    if (!wh) throw new NotFoundException('Warehouse not found');

    const data: any = {
      companyId,
      orderId,
      warehouseId,
      operatorId,
      status: 'started',
      startedAt: new Date(),
    };

    let rec: any;
    try {
      rec = await this.prisma.recording.create({ data });
    } catch (e1: any) {
      delete data.operatorId;
      data.userId = operatorId;
      try {
        rec = await this.prisma.recording.create({ data });
      } catch (e2: any) {
        throw new BadRequestException(
          `Recording create failed: ${e2?.message || e1?.message || e2}`,
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

    const key = this.storage.recordingSegmentKey
      ? this.storage.recordingSegmentKey(companyId, recordingId, segmentIndex)
      : `tenants/${companyId}/recordings/${recordingId}/seg-${segmentIndex}.webm`;

    const presign = await this.storage.presignPut(key, contentType);
    return { ...presign, segmentIndex, recordingId };
  }

  async addSegment(
    companyId: string,
    recordingId: string,
    dto: {
      segmentIndex?: number;
      index?: number;
      contentType?: string;
      storageKey?: string;
      durationSec?: number;
    },
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId },
    });
    if (!rec) throw new NotFoundException('Recording not found');

    const segmentIndex = dto.segmentIndex ?? dto.index ?? 0;
    const contentType = dto.contentType ?? 'video/webm';
    const key =
      dto.storageKey ||
      (this.storage.recordingSegmentKey
        ? this.storage.recordingSegmentKey(companyId, recordingId, segmentIndex)
        : `tenants/${companyId}/recordings/${recordingId}/seg-${segmentIndex}.webm`);

    const presign = await this.storage.presignPut(key, contentType);
    return {
      ...presign,
      segmentIndex,
      recordingId,
      storageKey: key,
    };
  }

  async stop(
    companyId: string,
    recordingId: string,
    durationSec?: number,
    segmentCount?: number,
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId },
    });
    if (!rec) throw new NotFoundException('Recording not found');

    const data: any = { status: 'completed' };
    if (durationSec != null) data.durationSec = durationSec;
    data.stoppedAt = new Date();

    let updated: any;
    try {
      updated = await this.prisma.recording.update({
        where: { id: recordingId },
        data,
      });
    } catch {
      delete data.stoppedAt;
      updated = await this.prisma.recording.update({
        where: { id: recordingId },
        data,
      });
    }

    let evidence: any = null;
    try {
      evidence = await this.prisma.evidence.create({
        data: {
          companyId,
          orderId: rec.orderId,
          recordingId: rec.id,
          status: 'pending',
          frameCount: segmentCount ?? 0,
        } as any,
      });
      try {
        const packKey = this.storage.evidencePackKey
          ? this.storage.evidencePackKey(companyId, evidence.id)
          : `tenants/${companyId}/evidence/${evidence.id}/pack.zip`;
        await this.prisma.evidence.update({
          where: { id: evidence.id },
          data: { status: 'ready', storageKey: packKey } as any,
        });
        evidence = { ...evidence, status: 'ready', storageKey: packKey };
      } catch {
        await this.prisma.evidence.update({
          where: { id: evidence.id },
          data: { status: 'ready' } as any,
        });
      }
    } catch (e: any) {
      console.error('[recording.stop] evidence:', e?.message);
    }

    try {
      await this.prisma.order.update({
        where: { id: rec.orderId },
        data: { status: 'evidence_ready' as any },
      });
    } catch (_) {}

    return { recording: updated, evidence };
  }
  async pause(companyId: string, id: string) {
    const rec = await this.prisma.recording.findFirst({ where: { id, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    const s = String(rec.status);
    if (!['started', 'recording', 'active'].includes(s)) {
      throw new BadRequestException(`Cannot pause from ${s}`);
    }
    return this.prisma.recording.update({
      where: { id },
      data: { status: 'paused' as any },
    });
  }

  async resume(companyId: string, id: string) {
    const rec = await this.prisma.recording.findFirst({ where: { id, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    if (String(rec.status) !== 'paused') {
      throw new BadRequestException(`Cannot resume from ${rec.status}`);
    }
    return this.prisma.recording.update({
      where: { id },
      data: { status: 'started' as any },
    });
  }

  async setChecksum(
    companyId: string,
    id: string,
    dto: { checksum: string; algorithm?: string; segmentIndex?: number },
  ) {
    const rec = await this.prisma.recording.findFirst({ where: { id, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    const meta = ((rec as any).metadata as any) || {};
    const checksums = meta.checksums || [];
    checksums.push({
      segmentIndex: dto.segmentIndex ?? 0,
      algorithm: dto.algorithm ?? 'sha256',
      checksum: dto.checksum,
      at: new Date().toISOString(),
    });
    return this.prisma.recording.update({
      where: { id },
      data: {
        checksum: dto.checksum,
        metadata: { ...meta, checksums },
      } as any,
    });
  }
}