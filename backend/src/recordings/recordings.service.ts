import {
  Injectable, Logger, NotFoundException, BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class RecordingsService {
  private readonly logger = new Logger(RecordingsService.name);

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
    return this.prisma.recording.create({
      data: { companyId, orderId, warehouseId, operatorId, status: 'started' },
    });
  }

  async presignSegment(
    companyId: string,
    recordingId: string,
    segmentIndex: number,
    contentType = 'video/webm',
  ) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    const key = `${companyId}/recordings/${recordingId}/seg_${segmentIndex}.webm`;
    const signed = await this.storage.presignPut(key, contentType);
    return {
      ...signed,
      segmentIndex,
      recordingId,
      key,
      storageKey: key,
      uploadUrl: (signed as any).uploadUrl || (signed as any).url,
    };
  }

  async registerSegment(
    companyId: string,
    recordingId: string,
    dto: {
      segmentIndex: number;
      storageKey: string;
      checksum?: string;
      sizeBytes?: number;
      durationMs?: number;
    },
  ) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');
    const size = BigInt(dto.sizeBytes ?? 0);
    const segment = await this.prisma.recordingSegment.create({
      data: {
        recordingId,
        companyId,
        sequence: dto.segmentIndex,
        b2Key: dto.storageKey,
        sizeBytes: size,
        checksum: dto.checksum,
        durationSec: dto.durationMs != null ? Math.round(dto.durationMs / 1000) : null,
      },
    });
    await this.prisma.recording.update({
      where: { id: recordingId },
      data: {
        segmentCount: { increment: 1 },
        totalBytes: { increment: size },
        b2Prefix: `${companyId}/recordings/${recordingId}/`,
      },
    });
    return segment;
  }

  async stop(
    companyId: string,
    recordingId: string,
    durationSec?: number,
    segmentCount?: number,
  ) {
    const rec = await this.prisma.recording.findFirst({ where: { id: recordingId, companyId } });
    if (!rec) throw new NotFoundException('Recording not found');

    const updated = await this.prisma.recording.update({
      where: { id: recordingId },
      data: {
        status: 'completed',
        completedAt: new Date(),
        ...(durationSec != null ? { durationSec } : {}),
        ...(segmentCount != null ? { segmentCount } : {}),
      },
    });

    const segs = await this.prisma.recordingSegment.findMany({
      where: { recordingId },
      orderBy: { sequence: 'asc' },
      take: 1,
    });
    const sourceKey = segs[0]?.b2Key || `${companyId}/recordings/${recordingId}/seg_0.webm`;

    let evidence = await this.prisma.evidence.findUnique({
      where: { recordingId: rec.id },
    });

    if (!evidence) {
      try {
        evidence = await this.prisma.evidence.create({
          data: {
            companyId,
            orderId: rec.orderId,
            recordingId: rec.id,
            status: 'pending',
            frameCount: 0,
          },
        });
      } catch (e: any) {
        this.logger.error(`EVIDENCE_CREATE_FAIL: ${e?.message}`);
        // surface to client so we stop guessing
        throw new BadRequestException(`Evidence create failed: ${e?.message}`);
      }
    } else {
      evidence = await this.prisma.evidence.update({
        where: { id: evidence.id },
        data: { frameCount: 0, status: 'pending' },
      });
    }

    this.logger.log(`EVIDENCE_OK id=${evidence.id} sourceKey=${sourceKey}`);

    return {
      recording: updated,
      evidence,
      processHint: {
        sourceKey,
        note: 'POST /evidence/:id/process-b2 after client uploaded video bytes to B2',
      },
    };
  }
}