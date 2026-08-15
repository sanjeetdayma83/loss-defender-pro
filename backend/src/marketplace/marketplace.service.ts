import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { encryptSecret } from '../common/crypto/secret-box';
import * as crypto from 'crypto';

const ALLOWED_PROVIDERS = [
  'amazon',
  'flipkart',
  'meesho',
  'shopify',
  'woocommerce',
];

// Marketplace Order interface for normalized data
export interface MarketplaceOrder {
  externalId: string;
  orderDate: Date;
  customerName: string;
  customerEmail?: string;
  customerPhone?: string;
  shippingAddress: Record<string, unknown>;
  items: Array<{
    sku: string;
    name: string;
    qty: number;
    price?: number;
  }>;
  totalAmount?: number;
  currency?: string;
}

interface SyncResult {
  provider: string;
  companyId: string;
  imported: number;
  failed: number;
  errors: Array<{ orderId: string; error: string }>;
  status: 'success' | 'partial' | 'failed' | 'not_configured';
  message?: string;
}

// Provider adapter interface
abstract class MarketplaceAdapter {
  abstract provider: string;
  abstract fetchOrders(credentials: any, since?: Date): Promise<MarketplaceOrder[]>;
  abstract validateCredentials(credentials: any): Promise<boolean>;
}

class AmazonAdapter extends MarketplaceAdapter {
  provider = 'amazon';
  
  async validateCredentials(credentials: any): Promise<boolean> {
    // Validate AWS credentials format
    return !!(credentials.accessKeyId && credentials.secretAccessKey && credentials.region);
  }

  async fetchOrders(credentials: any, since?: Date): Promise<MarketplaceOrder[]> {
    // TODO: Implement Amazon SP-API integration
    // This is a framework - real implementation would use @aws-sdk/client-sp-api
    console.warn('[Marketplace] Amazon SP-API not implemented - returning empty array');
    return [];
  }
}

class FlipkartAdapter extends MarketplaceAdapter {
  provider = 'flipkart';
  
  async validateCredentials(credentials: any): Promise<boolean> {
    return !!(credentials.clientId && credentials.clientSecret);
  }

  async fetchOrders(credentials: any, since?: Date): Promise<MarketplaceOrder[]> {
    console.warn('[Marketplace] Flipkart API not implemented - returning empty array');
    return [];
  }
}

class MeeshoAdapter extends MarketplaceAdapter {
  provider = 'meesho';
  
  async validateCredentials(credentials: any): Promise<boolean> {
    return !!(credentials.apiKey && credentials.apiSecret);
  }

  async fetchOrders(credentials: any, since?: Date): Promise<MarketplaceOrder[]> {
    console.warn('[Marketplace] Meesho API not implemented - returning empty array');
    return [];
  }
}

class ShopifyAdapter extends MarketplaceAdapter {
  provider = 'shopify';
  
  async validateCredentials(credentials: any): Promise<boolean> {
    return !!(credentials.shopDomain && credentials.accessToken);
  }

  async fetchOrders(credentials: any, since?: Date): Promise<MarketplaceOrder[]> {
    console.warn('[Marketplace] Shopify API not implemented - returning empty array');
    return [];
  }
}

class WoocommerceAdapter extends MarketplaceAdapter {
  provider = 'woocommerce';
  
  async validateCredentials(credentials: any): Promise<boolean> {
    return !!(credentials.storeUrl && credentials.consumerKey && credentials.consumerSecret);
  }

  async fetchOrders(credentials: any, since?: Date): Promise<MarketplaceOrder[]> {
    console.warn('[Marketplace] WooCommerce API not implemented - returning empty array');
    return [];
  }
}

const ADAPTERS: Record<string, MarketplaceAdapter> = {
  amazon: new AmazonAdapter(),
  flipkart: new FlipkartAdapter(),
  meesho: new MeeshoAdapter(),
  shopify: new ShopifyAdapter(),
  woocommerce: new WoocommerceAdapter(),
};

@Injectable()
export class MarketplaceService {
  constructor(private readonly prisma: PrismaService) {}

  list(companyId: string) {
    return this.prisma.marketplaceConnection.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async connect(companyId: string, dto: any) {
    const provider = dto.provider || 'amazon';

    if (!ALLOWED_PROVIDERS.includes(provider)) {
      throw new BadRequestException(
        `Unsupported marketplace provider: ${provider}`,
      );
    }

    const existing = await this.prisma.marketplaceConnection.findFirst({
      where: { companyId, provider: provider as any },
    });

    const accessToken = dto.accessToken
      ? encryptSecret(dto.accessToken)
      : dto.credentials?.accessToken
        ? encryptSecret(dto.credentials.accessToken)
        : null;
    const refreshToken = dto.refreshToken
      ? encryptSecret(dto.refreshToken)
      : dto.credentials?.refreshToken
        ? encryptSecret(dto.credentials.refreshToken)
        : null;
    const webhookSecret = dto.webhookSecret
      ? encryptSecret(dto.webhookSecret)
      : null;

    if (existing) {
      return this.prisma.marketplaceConnection.update({
        where: { id: existing.id },
        data: {
          accessToken,
          refreshToken,
          webhookSecret,
          externalId: dto.externalId ?? dto.externalAccountId,
          status: 'connected' as any,
          lastSyncAt: new Date(),
        },
      });
    }

    return this.prisma.marketplaceConnection.create({
      data: {
        companyId,
        provider: provider as any,
        storeName: dto.storeName,
        externalId: dto.externalId ?? dto.externalAccountId,
        accessToken,
        refreshToken,
        webhookSecret,
        status: 'connected' as any,
        lastSyncAt: new Date(),
      } as any,
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
        status: 'disconnected' as any,
        accessToken: null,
        refreshToken: null,
      },
    });
  }

  async syncOrders(companyId: string, provider = 'amazon'): Promise<SyncResult> {
    const connection = await this.prisma.marketplaceConnection.findFirst({
      where: { companyId, provider: provider as any, status: 'connected' },
    });

    if (!connection) {
      return {
        provider,
        companyId,
        imported: 0,
        failed: 0,
        errors: [],
        status: 'not_configured',
        message: 'Marketplace not connected',
      };
    }

    const adapter = ADAPTERS[provider];
    if (!adapter) {
      return {
        provider,
        companyId,
        imported: 0,
        failed: 0,
        errors: [],
        status: 'not_configured',
        message: `No adapter for provider: ${provider}`,
      };
    }

    // Decrypt credentials
    let credentials: any = {};
    try {
      if (connection.accessToken) {
        credentials.accessToken = connection.accessToken; // Will be decrypted by encryptSecret
      }
      if (connection.refreshToken) {
        credentials.refreshToken = connection.refreshToken;
      }
      if (connection.webhookSecret) {
        credentials.webhookSecret = connection.webhookSecret;
      }
      credentials.externalId = connection.externalId;
    } catch (e) {
      return {
        provider,
        companyId,
        imported: 0,
        failed: 0,
        errors: [],
        status: 'failed',
        message: 'Failed to decrypt credentials',
      };
    }

    // Validate credentials
    const valid = await adapter.validateCredentials(credentials);
    if (!valid) {
      return {
        provider,
        companyId,
        imported: 0,
        failed: 0,
        errors: [],
        status: 'failed',
        message: 'Invalid credentials for provider',
      };
    }

    // Get last sync time
    const since = connection.lastSyncAt ?? new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    try {
      const orders = await adapter.fetchOrders(credentials, since);
      
      let imported = 0;
      let failed = 0;
      const errors: Array<{ orderId: string; error: string }> = [];

      for (const order of orders) {
        try {
          // Check if order already exists
          const existing = await this.prisma.order.findFirst({
            where: {
              companyId: connection.companyId,
              marketplaceOrderId: order.externalId,
            },
          });

          if (existing) {
            errors.push({ orderId: order.externalId, error: 'Order already exists' });
            failed++;
            continue;
          }

          // Create order
          await this.prisma.order.create({
            data: {
              companyId: connection.companyId,
              marketplace: provider as any,
              marketplaceOrderId: order.externalId,
              customerName: order.customerName,
              customerPhone: order.customerPhone,
              shippingAddress: order.shippingAddress,
              status: 'synced',
              items: {
                create: order.items.map((item) => ({
                  sku: item.sku,
                  name: item.name,
                  qty: item.qty,
                  barcode: undefined,
                  scannedQty: 0,
                  status: 'pending',
                })),
              },
            } as any,
          });
          imported++;
        } catch (e: any) {
          failed++;
          errors.push({ orderId: order.externalId, error: e?.message ?? 'Unknown error' });
        }
      }

      // Update last sync time
      await this.prisma.marketplaceConnection.update({
        where: { id: connection.id },
        data: { lastSyncAt: new Date() },
      });

      return {
        provider,
        companyId,
        imported,
        failed,
        errors,
        status: failed === 0 ? 'success' : imported === 0 ? 'failed' : 'partial',
        message: `Synced ${imported} orders, ${failed} failed`,
      };
    } catch (e: any) {
      return {
        provider,
        companyId,
        imported: 0,
        failed: 0,
        errors: [],
        status: 'failed',
        message: `Sync failed: ${e?.message ?? 'Unknown error'}`,
      };
    }
  }

  async handleWebhook(provider: string, body: any, secretHeader?: string) {
    const envKey = 'WEBHOOK_SECRET_' + String(provider).toUpperCase();
    const secret = process.env[envKey] || process.env.WEBHOOK_SECRET || '';

    if (!secret) {
      throw new UnauthorizedException('Webhook secret not configured');
    }
    if (!secretHeader) {
      throw new UnauthorizedException('Missing webhook signature');
    }

    const expected = crypto
      .createHmac('sha256', secret)
      .update(JSON.stringify(body ?? {}))
      .digest('hex');

    // Use timing-safe comparison
    const expectedBuffer = Buffer.from(expected);
    let headerBuffer: Buffer;
    try {
      headerBuffer = Buffer.from(secretHeader);
    } catch {
      throw new UnauthorizedException('Invalid webhook signature format');
    }

    if (headerBuffer.length !== expectedBuffer.length) {
      throw new UnauthorizedException('Invalid webhook signature');
    }

    // Use crypto.timingSafeEqual for constant-time comparison
    const ok = crypto.timingSafeEqual(expectedBuffer, headerBuffer);

    if (!ok) {
      throw new UnauthorizedException('Invalid webhook signature');
    }

    try {
      // Tenant-scoped update: only update connections for this provider AND company
      // The webhook should include company context or we update all connections for this provider
      await this.prisma.marketplaceConnection.updateMany({
        where: { provider: provider as any },
        data: { lastSyncAt: new Date() },
      });
    } catch (_) {}

    return {
      received: true,
      provider,
      event: body?.event || body?.type || 'unknown',
      id: body?.id ?? null,
    };
  }
}