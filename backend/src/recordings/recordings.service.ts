import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { warehouseScope, assertWarehouseAccess } from '../common/utils/warehouse-scope';

@Injectable()
export class RecordingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  list(companyId: string, user?: { role?: string; warehouseId?: string | null }) {
    return this.prisma.recording.findMany({
      where: { companyId, ...warehouseScope(user || {}, {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const rec = await this.prisma.recording.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
      include: { order: true } as any,
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);
    return rec;
  }

  async getDownload(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const rec = await this.prisma.recording.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);

    const meta = ((rec as any).metadata as any) || {};
    const key =
      (rec as any).storageKey ||
      meta.storageKey ||
      meta.lastSegmentKey ||
      null;

    if (!key) {
      return {
        recordingId: id,
        url: null,
        message: 'No storage key yet — upload segments first',
      };
    }

    try {
      if (typeof (this.storage as any).presignGet === 'function') {
        const signed = await (this.storage as any).presignGet(key);
        return {
          recordingId: id,
          key,
          url: signed?.url ?? null,
          expiresIn: signed?.expiresIn,
        };
      }
    } catch (e: any) {
      return {
        recordingId: id,
        key,
        url: null,
        message: e?.message || 'presign failed',
      };
    }

    return { recordingId: id, key, url: null, message: 'presignGet not available' };
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
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);

    const key = (this.storage as any).recordingSegmentKey
      ? (this.storage as any).recordingSegmentKey(
          companyId,
          recordingId,
          segmentIndex,
        )
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
      sequence?: number;
      contentType?: string;
      storageKey?: string;
      b2Key?: string;
      durationSec?: number;
      checksum?: string;
      sizeBytes?: number;
      [key: string]: unknown;
    },
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);

    const segmentIndex =
      dto.segmentIndex ?? dto.index ?? dto.sequence ?? 0;
    const contentType = dto.contentType ?? 'video/webm';
    const key = dto.storageKey || dto.b2Key ||
      ((this.storage as any).recordingSegmentKey
        ? (this.storage as any).recordingSegmentKey(
            companyId,
            recordingId,
            segmentIndex,
          )
        : `tenants/${companyId}/recordings/${recordingId}/seg-${segmentIndex}.webm`);

    const presign = await this.storage.presignPut(key, contentType);
    return {
      ...presign,
      segmentIndex,
      recordingId,
      storageKey: key,
    };
  }

  async pause(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const rec = await this.prisma.recording.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);
    const meta = ((rec as any).metadata as any) || {};
    try {
      return await this.prisma.recording.update({
        where: { id },
        data: {
          status: 'paused' as any,
          metadata: {
            ...meta,
            paused: true,
            pausedAt: new Date().toISOString(),
          },
        } as any,
      });
    } catch {
      return this.prisma.recording.update({
        where: { id },
        data: {
          metadata: {
            ...meta,
            paused: true,
            pausedAt: new Date().toISOString(),
          },
        } as any,
      });
    }
  }

  async resume(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const rec = await this.prisma.recording.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);
    const meta = ((rec as any).metadata as any) || {};
    try {
      return await this.prisma.recording.update({
        where: { id },
        data: {
          status: 'started' as any,
          metadata: {
            ...meta,
            paused: false,
            resumedAt: new Date().toISOString(),
          },
        } as any,
      });
    } catch {
      return this.prisma.recording.update({
        where: { id },
        data: {
          metadata: {
            ...meta,
            paused: false,
            resumedAt: new Date().toISOString(),
          },
        } as any,
      });
    }
  }

  async setChecksum(
    companyId: string,
    id: string,
    dto: { checksum: string; algorithm?: string; segmentIndex?: number },
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);
    const meta = ((rec as any).metadata as any) || {};
    const checksums = Array.isArray(meta.checksums)
      ? [...meta.checksums]
      : [];
    checksums.push({
      segmentIndex: dto.segmentIndex ?? 0,
      algorithm: dto.algorithm ?? 'sha256',
      checksum: dto.checksum,
      at: new Date().toISOString(),
    });
    return this.prisma.recording.update({
      where: { id },
      data: { metadata: { ...meta, checksums } } as any,
    });
  }

  async stop(
    companyId: string,
    recordingId: string,
    durationSec?: number,
    segmentCount?: number,
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const rec = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId, ...warehouseScope(user || {}, {}) },
    });
    if (!rec) throw new NotFoundException('Recording not found');
    assertWarehouseAccess(user || {}, rec.warehouseId);

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

    const frameCount = Math.max(segmentCount ?? 1, 1) * 3;
    const frames = Array.from({ length: frameCount }, (_, i) => ({
      index: i,
      label: `Frame ${i + 1}`,
      status: 'pending_extract',
      type: i % 3 === 0 ? 'keyframe' : 'sample',
    }));

    let evidence: any = null;
    try {
      evidence = await this.prisma.evidence.create({
        data: {
          companyId,
          orderId: rec.orderId,
          recordingId: rec.id,
          warehouseId: rec.warehouseId,
          status: 'pending',
          frameCount,
        } as any,
      });

      const packKey = (this.storage as any).evidencePackKey
        ? (this.storage as any).evidencePackKey(companyId, evidence.id)
        : `tenants/${companyId}/evidence/${evidence.id}/pack.zip`;

      try {
        await this.prisma.evidence.update({
          where: { id: evidence.id },
          data: {
            status: 'ready',
            storageKey: packKey,
            frameCount,
            metadata: {
              frames,
              processingStatus: 'frames_queued',
              queuedAt: new Date().toISOString(),
            },
          } as any,
        });
        evidence = {
          ...evidence,
          status: 'ready',
          storageKey: packKey,
          frameCount,
          metadata: { frames, processingStatus: 'frames_queued' },
        };
      } catch {
        try {
          await this.prisma.evidence.update({
            where: { id: evidence.id },
            data: {
              status: 'ready',
              frameCount,
              metadata: { frames, processingStatus: 'frames_queued' },
            } as any,
          });
          evidence = { ...evidence, status: 'ready', frameCount };
        } catch (e: any) {
          console.error('[stop] evidence meta:', e?.message);
        }
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
}
