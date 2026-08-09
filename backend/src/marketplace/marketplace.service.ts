import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConnectMarketplaceDto } from './dto/connect-marketplace.dto';
import {
  Marketplace,
  MarketplaceConnectionStatus,
  MarketplaceProvider,
} from '@prisma/client';

@Injectable()
export class MarketplaceService {
  constructor(private readonly prisma: PrismaService) {}

  list(companyId: string) {
    return this.prisma.marketplaceConnection.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        provider: true,
        storeName: true,
        externalId: true,
        status: true,
        lastSyncAt: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async connect(companyId: string, dto: ConnectMarketplaceDto) {
    const existing = await this.prisma.marketplaceConnection.findFirst({
      where: {
        companyId,
        provider: dto.provider,
        storeName: dto.storeName ?? null,
      },
    });
    if (existing) {
      return this.prisma.marketplaceConnection.update({
        where: { id: existing.id },
        data: {
          accessToken: dto.accessToken,
          refreshToken: dto.refreshToken,
          webhookSecret: dto.webhookSecret,
          externalId: dto.externalId,
          status: MarketplaceConnectionStatus.connected,
          lastSyncAt: new Date(),
        },
      });
    }
    return this.prisma.marketplaceConnection.create({
      data: {
        companyId,
        provider: dto.provider,
        storeName: dto.storeName,
        externalId: dto.externalId,
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        webhookSecret: dto.webhookSecret,
        status: MarketplaceConnectionStatus.connected,
        lastSyncAt: new Date(),
      },
    });
  }

  async disconnect(companyId: string, id: string) {
    const row = await this.prisma.marketplaceConnection.findFirst({
      where: { id, companyId },
    });
    if (!row) throw new NotFoundException('Connection not found');
    return this.prisma.marketplaceConnection.update({
      where: { id },
      data: {
        status: MarketplaceConnectionStatus.disconnected,
        accessToken: null,
        refreshToken: null,
      },
    });
  }

  /** Map webhook provider string → MarketplaceProvider + Order.Marketplace */
  private parseProvider(provider: string): {
    conn: MarketplaceProvider;
    order: Marketplace;
  } {
    const p = (provider || 'manual').toLowerCase();
    const connValues = Object.values(MarketplaceProvider) as string[];
    const orderValues = Object.values(Marketplace) as string[];

    const conn = (connValues.includes(p)
      ? p
      : connValues.includes('manual')
        ? 'manual'
        : connValues[0]) as MarketplaceProvider;

    const order = (orderValues.includes(p)
      ? p
      : orderValues.includes('manual')
        ? 'manual'
        : orderValues[0]) as Marketplace;

    return { conn, order };
  }

  async handleWebhook(
    provider: string,
    payload: Record<string, unknown>,
    secretHeader?: string,
  ) {
    const { conn: providerConn, order: providerOrder } =
      this.parseProvider(provider);

    const externalId =
      (payload['storeId'] as string) ||
      (payload['sellerId'] as string) ||
      undefined;

    const conn = await this.prisma.marketplaceConnection.findFirst({
      where: {
        provider: providerConn,
        status: MarketplaceConnectionStatus.connected,
        ...(externalId ? { externalId } : {}),
      },
      orderBy: { updatedAt: 'desc' },
    });
    if (!conn) return { accepted: false, reason: 'no_connection' };

    if (
      conn.webhookSecret &&
      secretHeader &&
      conn.webhookSecret !== secretHeader
    ) {
      return { accepted: false, reason: 'invalid_secret' };
    }

    const orderRef =
      (payload['orderId'] as string) ||
      (payload['marketplaceOrderId'] as string) ||
      `WH-${Date.now()}`;

    const existing = await this.prisma.order.findFirst({
      where: { companyId: conn.companyId, marketplaceOrderId: orderRef },
    });
    if (existing) {
      await this.prisma.marketplaceConnection.update({
        where: { id: conn.id },
        data: { lastSyncAt: new Date() },
      });
      return { accepted: true, orderId: existing.id, duplicate: true };
    }

    const order = await this.prisma.order.create({
      data: {
        companyId: conn.companyId,
        marketplace: providerOrder,
        marketplaceOrderId: orderRef,
        status: 'synced' as any,
      },
    });
    await this.prisma.marketplaceConnection.update({
      where: { id: conn.id },
      data: { lastSyncAt: new Date() },
    });
    return { accepted: true, orderId: order.id, duplicate: false };
  }
}