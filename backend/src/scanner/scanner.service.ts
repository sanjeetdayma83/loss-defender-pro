import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OrderItemStatus, OrderStatus } from '@prisma/client';
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

    if (
      !['synced', 'queued', 'packing', 'recording', 'scanned'].includes(
        String(order.status),
      )
    ) {
      throw new BadRequestException(`Cannot scan in status ${order.status}`);
    }

    // Duplicate barcode event (same code on order)
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

    // Same source of truth as OrdersService.scan — update scannedQty
    let scanPayload: any = null;
    if (match) {
      if (match.scannedQty >= match.qty) {
        throw new ConflictException(`SKU ${match.sku} already fully scanned`);
      }
      const newQty = match.scannedQty + 1;
      const itemStatus: OrderItemStatus =
        newQty >= match.qty ? 'matched' : 'partial';

      await this.prisma.orderItem.update({
        where: { id: match.id },
        data: { scannedQty: newQty, status: itemStatus },
      });

      const refreshed = await this.prisma.order.findFirst({
        where: { id: orderId },
        include: { items: true },
      });
      const allMatched = refreshed!.items.every((i) => i.scannedQty >= i.qty);
      if (allMatched) {
        await this.prisma.order.update({
          where: { id: orderId },
          data: { status: 'scanned' as OrderStatus },
        });
      } else if (['synced', 'queued'].includes(String(refreshed!.status))) {
        await this.prisma.order.update({
          where: { id: orderId },
          data: { status: 'packing' as OrderStatus },
        });
      }

      scanPayload = {
        sku: match.sku,
        scannedQty: newQty,
        qty: match.qty,
        itemStatus,
        allMatched,
      };
    }

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

    return {
      event,
      result,
      scan: scanPayload,
      alert:
        result === 'wrong_sku'
          ? {
              type: 'WRONG_SKU',
              message: `Expected ${expectedSku}, got ${code}`,
            }
          : result === 'unknown'
            ? {
                type: 'UNKNOWN_BARCODE',
                message: 'Barcode not in order items',
              }
            : null,
      orderStatus: order.status,
    };
  }
}