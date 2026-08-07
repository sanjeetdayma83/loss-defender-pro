import {
  Injectable, NotFoundException, BadRequestException, ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OrderStatus } from '@prisma/client';
import { tenantWhere } from '../common/utils/tenant';

@Injectable()
export class ScannerService {
  constructor(private readonly prisma: PrismaService) {}

  async scan(
    companyId: string,
    operatorId: string,
    orderId: string,
    barcode: string,
    expectedSku?: string,
  ) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(companyId, { id: orderId }),
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    const code = barcode.trim();
    if (!code) throw new BadRequestException('Empty barcode');

    const prior = await this.prisma.scanEvent.findFirst({
      where: { companyId, orderId, barcode: code },
    });
    if (prior) {
      throw new ConflictException({
        code: 'DUPLICATE_SCAN',
        message: 'Barcode already scanned for this order',
        scannedAt: prior.createdAt,
      });
    }

    const items = ((order as any).items as any[]) ?? [];
    const match = items.find(
      (i) =>
        i.sku === code ||
        i.barcode === code ||
        i.ean === code ||
        i.marketplaceSku === code,
    );

    let result: 'matched' | 'unknown' | 'wrong_sku' = 'unknown';
    if (match) result = 'matched';
    else if (expectedSku && expectedSku !== code) result = 'wrong_sku';

    const event = await this.prisma.scanEvent.create({
      data: {
        companyId,
        orderId,
        operatorId,
        barcode: code,
        result,
        expectedSku: expectedSku ?? null,
        matchedItemId: match?.id ?? null,
      },
    });

    if (result === 'matched') {
      const cur = String(order.status).toLowerCase();
      if (cur === 'queued' || cur === 'synced') {
        await this.prisma.order.update({
          where: { id: orderId },
          data: { status: 'scanned' as OrderStatus },
        });
      }
    }

    return {
      event,
      result,
      alert:
        result === 'wrong_sku'
          ? { type: 'WRONG_SKU', message: `Expected ${expectedSku}, got ${code}` }
          : result === 'unknown'
            ? { type: 'UNKNOWN_BARCODE', message: 'Barcode not in order items' }
            : null,
      orderStatus: order.status,
    };
  }
}
