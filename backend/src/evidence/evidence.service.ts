import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class EvidenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  list(companyId: string) {
    return this.prisma.evidence.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string) {
    const row = await this.prisma.evidence.findFirst({ where: { id, companyId } });
    if (!row) throw new NotFoundException('Evidence not found');
    return row;
  }

  async getDownloadUrl(companyId: string, id: string) {
    const row = await this.prisma.evidence.findFirst({ where: { id, companyId } });
    if (!row) throw new NotFoundException('Evidence not found');
    const packKey = (row as any).packKey;
    if (!packKey) {
      return { configured: false, downloadUrl: null, message: 'No packKey yet' };
    }
    const signed = await this.storage.presignGet(packKey);
    return { ...signed, evidenceId: id };
  }

  /** Called from RecordingsService.stop — creates evidence + optional pack */
  async createFromRecording(
    companyId: string,
    orderId: string,
    recordingId: string,
    segmentCount = 1,
  ) {
    let evidence = await this.prisma.evidence.create({
      data: {
        companyId,
        orderId,
        recordingId,
        status: 'pending',
        frameCount: segmentCount,
      } as any,
    });

    // Always generate a logical pack key (even if B2 not configured)
    const packKey = this.storage.evidencePackKey(companyId, evidence.id);

    const newStatus = this.storage.isConfigured() ? 'ready' : 'pending';

    evidence = await this.prisma.evidence.update({
      where: { id: evidence.id },
      data: { packKey, status: newStatus } as any,
    });

    return evidence;
  }
}
