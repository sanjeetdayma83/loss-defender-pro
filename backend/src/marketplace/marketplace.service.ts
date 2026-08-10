import {
  Injectable,
  NotFoundException,
  BadRequestException,
  UnauthorizedException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MarketplaceCryptoService } from './marketplace-crypto.service';
import { createHmac, createHash, timingSafeEqual } from 'crypto';

interface MarketplaceCredentials {
  accessToken?: string;
  refreshToken?: string;
  clientId?: string;
  clientSecret?: string;
  awsAccessKeyId?: string;
  awsSecretAccessKey?: string;
  awsSessionToken?: string;
  sellerId?: string;
  marketplaceId?: string;
  region?: string;
  endpoint?: string;
  apiKey?: string;
  apiSecret?: string;
  baseUrl?: string;
  ordersPath?: string;
  authHeader?: string;
  authScheme?: string;
}

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: MarketplaceCryptoService,
  ) {}

  private safe(row: any) {
    return {
      id: row.id,
      companyId: row.companyId,
      provider: row.provider,
      storeName: row.storeName,
      externalId: row.externalId,
      status: row.status,
      lastSyncAt: row.lastSyncAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

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

  async connect(companyId: string, dto: any) {
    const provider = String(dto?.provider || '').toLowerCase();
    if (!provider) throw new BadRequestException('provider required');

    const input: MarketplaceCredentials = {
      ...(dto?.credentials ?? {}),
      accessToken: dto?.accessToken ?? dto?.credentials?.accessToken,
      refreshToken: dto?.refreshToken ?? dto?.credentials?.refreshToken,
      clientId: dto?.clientId ?? dto?.credentials?.clientId,
      clientSecret: dto?.clientSecret ?? dto?.credentials?.clientSecret,
      awsAccessKeyId: dto?.awsAccessKeyId ?? dto?.credentials?.awsAccessKeyId,
      awsSecretAccessKey:
        dto?.awsSecretAccessKey ?? dto?.credentials?.awsSecretAccessKey,
      awsSessionToken: dto?.awsSessionToken ?? dto?.credentials?.awsSessionToken,
      sellerId: dto?.sellerId ?? dto?.credentials?.sellerId,
      marketplaceId: dto?.marketplaceId ?? dto?.credentials?.marketplaceId,
      region: dto?.region ?? dto?.credentials?.region,
      endpoint: dto?.endpoint ?? dto?.credentials?.endpoint,
      apiKey: dto?.apiKey ?? dto?.credentials?.apiKey,
      apiSecret: dto?.apiSecret ?? dto?.credentials?.apiSecret,
      baseUrl: dto?.baseUrl ?? dto?.credentials?.baseUrl,
      ordersPath: dto?.ordersPath ?? dto?.credentials?.ordersPath,
      authHeader: dto?.authHeader ?? dto?.credentials?.authHeader,
      authScheme: dto?.authScheme ?? dto?.credentials?.authScheme,
    };

    if (
      !input.accessToken &&
      !input.refreshToken &&
      !input.apiKey &&
      !input.clientId
    ) {
      throw new BadRequestException('Marketplace access credentials are required');
    }

    const encryptedCredentials = this.crypto.encrypt(JSON.stringify(input));
    const data: any = {
      accessToken: this.crypto.encrypt(input.accessToken),
      refreshToken: this.crypto.encrypt(input.refreshToken),
      webhookSecret: this.crypto.encrypt(dto.webhookSecret),
      externalId: dto.externalId ?? dto.externalAccountId ?? input.sellerId,
      meta: {
        credentialsEncrypted: encryptedCredentials,
        ...(dto.meta ?? {}),
      },
      status: 'connected',
      lastSyncAt: null,
    };

    const existing = await this.prisma.marketplaceConnection.findFirst({
      where: {
        companyId,
        provider: provider as any,
        storeName: dto.storeName ?? null,
      },
    });

    const row = existing
      ? await this.prisma.marketplaceConnection.update({
          where: { id: existing.id },
          data,
        })
      : await this.prisma.marketplaceConnection.create({
          data: {
            companyId,
            provider: provider as any,
            storeName: dto.storeName,
            ...data,
          } as any,
        });

    return this.safe(row);
  }

  async disconnect(companyId: string, id: string) {
    const row = await this.prisma.marketplaceConnection.findFirst({
      where: { id, companyId },
    });
    if (!row) throw new NotFoundException('Connection not found');
    const out = await this.prisma.marketplaceConnection.update({
      where: { id },
      data: {
        status: 'disconnected',
        accessToken: null,
        refreshToken: null,
        webhookSecret: null,
        meta: null,
      },
    });
    return this.safe(out);
  }

  async syncOrders(companyId: string, provider = 'amazon') {
    const p = String(provider).toLowerCase();
    const c = await this.prisma.marketplaceConnection.findFirst({
      where: { companyId, provider: p as any, status: 'connected' },
    });
    if (!c) throw new NotFoundException(`No connected ${p} marketplace account`);

    const credentials = this.getCredentials(c);
    if (p === 'flipkart') {
      const token = this.crypto.decrypt(c.accessToken);
      if (!token) throw new BadRequestException('Flipkart access token is missing; reconnect the account');
      return this.syncFlipkart(companyId, c.id, token);
    }
    if (p === 'amazon') return this.syncAmazon(companyId, c.id, credentials);
    if (p === 'meesho') return this.syncMeesho(companyId, c.id, credentials);
    throw new ServiceUnavailableException(`${p} order connector is not configured`);
  }

  private getCredentials(connection: any): MarketplaceCredentials {
    const encrypted = connection?.meta?.credentialsEncrypted;
    if (encrypted) {
      try {
        return JSON.parse(this.crypto.decrypt(encrypted) ?? '{}');
      } catch {
        throw new BadRequestException('Marketplace credentials are corrupted; reconnect the account');
      }
    }

    return {
      accessToken: this.crypto.decrypt(connection.accessToken),
      refreshToken: this.crypto.decrypt(connection.refreshToken),
    };
  }

  private async syncAmazon(
    companyId: string,
    connectionId: string,
    credentials: MarketplaceCredentials,
  ) {
    const refreshToken = credentials.refreshToken ?? credentials.accessToken;
    const clientId = credentials.clientId ?? process.env.AMAZON_SP_API_CLIENT_ID;
    const clientSecret = credentials.clientSecret ?? process.env.AMAZON_SP_API_CLIENT_SECRET;
    const awsAccessKeyId = credentials.awsAccessKeyId ?? process.env.AWS_ACCESS_KEY_ID;
    const awsSecretAccessKey = credentials.awsSecretAccessKey ?? process.env.AWS_SECRET_ACCESS_KEY;
    const awsSessionToken = credentials.awsSessionToken ?? process.env.AWS_SESSION_TOKEN;
    const marketplaceId = credentials.marketplaceId ?? process.env.AMAZON_MARKETPLACE_ID ?? 'A21TJRUUN4KGV';
    const sellerId = credentials.sellerId ?? process.env.AMAZON_SELLER_ID;
    const region = credentials.region ?? process.env.AMAZON_SP_API_REGION ?? 'eu-west-1';
    const endpoint = credentials.endpoint ?? process.env.AMAZON_SP_API_ENDPOINT ?? 'https://sellingpartnerapi-eu.amazon.com';

    if (!refreshToken || !clientId || !clientSecret || !awsAccessKeyId || !awsSecretAccessKey || !sellerId) {
      throw new BadRequestException(
        'Amazon SP-API is not configured. Provide clientId, clientSecret, refreshToken, AWS access key/secret and sellerId.',
      );
    }

    const accessToken = await this.getAmazonAccessToken(refreshToken, clientId, clientSecret);
    const createdAfter = new Date(
      Date.now() - Number(process.env.AMAZON_SYNC_DAYS ?? 30) * 24 * 60 * 60 * 1000,
    ).toISOString();

    let nextToken: string | undefined;
    let imported = 0;
    let received = 0;
    let pages = 0;

    do {
      const query: Record<string, string> = nextToken
        ? { NextToken: nextToken }
        : { MarketplaceIds: marketplaceId, CreatedAfter: createdAfter };
      const result = await this.amazonRequest(
        'GET',
        '/orders/v0/orders',
        query,
        undefined,
        accessToken,
        awsAccessKeyId,
        awsSecretAccessKey,
        awsSessionToken,
        region,
        endpoint,
      );

      const orders: any[] = result?.payload?.Orders ?? result?.Orders ?? [];
      nextToken = result?.payload?.NextToken ?? result?.NextToken;
      received += orders.length;
      pages++;

      for (const item of orders) {
        const oid = String(item.AmazonOrderId ?? '');
        if (!oid) continue;
        let order = await this.prisma.order.findFirst({
          where: { companyId, marketplace: 'amazon', marketplaceOrderId: oid },
        });

        const mapped = {
          status: this.mapAmazonStatus(item.OrderStatus),
          customerName: item.BuyerInfo?.BuyerName ?? undefined,
          customerPhone: item.BuyerInfo?.BuyerPhone ?? undefined,
          shippingAddress: item.ShippingAddress ?? undefined,
          awb: item.AmazonOrderId ?? undefined,
          metadata: item,
        } as any;

        if (order) {
          order = await this.prisma.order.update({ where: { id: order.id }, data: mapped });
        } else {
          order = await this.prisma.order.create({
            data: {
              companyId,
              marketplace: 'amazon',
              marketplaceOrderId: oid,
              ...mapped,
            } as any,
          });
          imported++;
        }

        await this.syncAmazonOrderItems(
          order.id,
          oid,
          accessToken,
          awsAccessKeyId,
          awsSecretAccessKey,
          awsSessionToken,
          region,
          endpoint,
        );
      }
    } while (nextToken && pages < 20);

    await this.prisma.marketplaceConnection.update({
      where: { id: connectionId },
      data: { lastSyncAt: new Date(), status: 'connected' },
    });

    return {
      provider: 'amazon',
      companyId,
      sellerId,
      marketplaceId,
      imported,
      received,
      pages,
      status: 'completed',
    };
  }

  private async syncAmazonOrderItems(
    orderId: string,
    amazonOrderId: string,
    accessToken: string,
    accessKey: string,
    secretKey: string,
    sessionToken: string | undefined,
    region: string,
    endpoint: string,
  ) {
    const result = await this.amazonRequest(
      'GET',
      `/orders/v0/orders/${encodeURIComponent(amazonOrderId)}/orderItems`,
      {},
      undefined,
      accessToken,
      accessKey,
      secretKey,
      sessionToken,
      region,
      endpoint,
    );
    const items: any[] = result?.payload?.OrderItems ?? result?.OrderItems ?? [];
    for (const item of items) {
      const sku = String(item.SellerSKU ?? item.ASIN ?? item.OrderItemId ?? 'unknown');
      const qty = Number(item.QuantityOrdered ?? 1) || 1;
      const existing = await this.prisma.orderItem.findFirst({ where: { orderId, sku } });
      const data: any = {
        name: item.Title ?? sku,
        qty,
        barcode: item.ASIN ?? null,
        metadata: item,
      };
      if (existing) await this.prisma.orderItem.update({ where: { id: existing.id }, data });
      else await this.prisma.orderItem.create({ data: { orderId, sku, ...data } });
    }
  }

  private async getAmazonAccessToken(
    refreshToken: string,
    clientId: string,
    clientSecret: string,
  ) {
    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: clientId,
      client_secret: clientSecret,
    });
    const response = await fetch('https://api.amazon.com/auth/o2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
      body,
    });
    if (!response.ok) {
      throw new BadRequestException(`Amazon LWA token exchange failed (${response.status})`);
    }
    const data: any = await response.json();
    if (!data.access_token) throw new BadRequestException('Amazon LWA response did not contain an access token');
    return String(data.access_token);
  }

  private async amazonRequest(
    method: string,
    path: string,
    query: Record<string, string>,
    body: unknown,
    accessToken: string,
    accessKey: string,
    secretKey: string,
    sessionToken: string | undefined,
    region: string,
    endpoint: string,
  ) {
    const url = new URL(path, endpoint);
    Object.entries(query).forEach(([key, value]) => url.searchParams.set(key, value));
    const host = url.host;
    const payload = body == null ? '' : JSON.stringify(body);
    const payloadHash = createHash('sha256').update(payload).digest('hex');
    const now = new Date();
    const amzDate = this.isoBasic(now);
    const dateStamp = amzDate.slice(0, 8);
    const canonicalQuery = [...url.searchParams.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${this.awsEncode(k)}=${this.awsEncode(v)}`)
      .join('&');
    const canonicalHeaders = `host:${host}\nx-amz-access-token:${accessToken}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
    const signedHeaders = 'host;x-amz-access-token;x-amz-content-sha256;x-amz-date';
    const canonicalRequest = `${method}\n${url.pathname}\n${canonicalQuery}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;
    const credentialScope = `${dateStamp}/${region}/execute-api/aws4_request`;
    const stringToSign = `AWS4-HMAC-SHA256\n${amzDate}\n${credentialScope}\n${createHash('sha256').update(canonicalRequest).digest('hex')}`;
    const signingKey = this.awsSigningKey(secretKey, dateStamp, region, 'execute-api');
    const signature = createHmac('sha256', signingKey).update(stringToSign).digest('hex');
    const authorization = `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;
    const headers: Record<string, string> = {
      host,
      'x-amz-access-token': accessToken,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      Authorization: authorization,
    };
    if (sessionToken) headers['x-amz-security-token'] = sessionToken;
    if (payload) headers['content-type'] = 'application/json';

    const response = await fetch(url, { method, headers, body: payload || undefined });
    const text = await response.text();
    let data: any = {};
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { raw: text };
    }
    if (!response.ok) {
      throw new BadRequestException(`Amazon SP-API request failed (${response.status}): ${JSON.stringify(data).slice(0, 500)}`);
    }
    return data;
  }

  private awsSigningKey(secret: string, date: string, region: string, service: string) {
    const kDate = createHmac('sha256', `AWS4${secret}`).update(date).digest();
    const kRegion = createHmac('sha256', kDate).update(region).digest();
    const kService = createHmac('sha256', kRegion).update(service).digest();
    return createHmac('sha256', kService).update('aws4_request').digest();
  }

  private isoBasic(date: Date) {
    return date.toISOString().replace(/[:-]|\.\d{3}/g, '');
  }

  private awsEncode(value: string) {
    return encodeURIComponent(value).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
  }

  private async syncMeesho(
    companyId: string,
    connectionId: string,
    credentials: MarketplaceCredentials,
  ) {
    const baseUrl = credentials.baseUrl ?? process.env.MEESHO_API_BASE_URL;
    const ordersPath = credentials.ordersPath ?? process.env.MEESHO_ORDERS_PATH;
    const apiKey = credentials.apiKey ?? process.env.MEESHO_API_KEY;
    const apiSecret = credentials.apiSecret ?? process.env.MEESHO_API_SECRET;
    const sellerId = credentials.sellerId ?? process.env.MEESHO_SELLER_ID;

    if (!baseUrl || !ordersPath || !apiKey) {
      throw new BadRequestException(
        'Meesho API is not configured. Provide the official seller API base URL, orders path and API key for your account.',
      );
    }

    const url = new URL(ordersPath, baseUrl);
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      [credentials.authHeader ?? process.env.MEESHO_AUTH_HEADER ?? 'Authorization']:
        `${credentials.authScheme ?? process.env.MEESHO_AUTH_SCHEME ?? 'Bearer'} ${apiKey}`,
    };
    if (apiSecret) headers['X-API-Secret'] = apiSecret;
    if (sellerId) headers['X-Seller-Id'] = sellerId;

    const response = await fetch(url, { method: 'GET', headers });
    const text = await response.text();
    let body: any = {};
    try {
      body = text ? JSON.parse(text) : {};
    } catch {
      body = { raw: text };
    }
    if (!response.ok) {
      throw new BadRequestException(`Meesho order sync failed (${response.status}): ${JSON.stringify(body).slice(0, 500)}`);
    }

    const items = this.extractMeeshoOrders(body);
    let imported = 0;
    for (const item of items) {
      const oid = String(item.orderId ?? item.order_id ?? item.id ?? item.orderNumber ?? '');
      if (!oid) continue;
      let order = await this.prisma.order.findFirst({
        where: { companyId, marketplace: 'meesho', marketplaceOrderId: oid },
      });
      const mapped: any = {
        status: this.mapStatus(item.status ?? item.orderStatus ?? item.order_status),
        customerName: item.customerName ?? item.customer_name ?? item.buyerName,
        customerPhone: item.customerPhone ?? item.customer_phone,
        shippingAddress: item.shippingAddress ?? item.shipping_address,
        awb: item.awb ?? item.awbNumber ?? item.awb_number,
        courier: item.courier ?? item.courierName ?? item.logisticsPartner,
        metadata: item,
      };
      if (order) order = await this.prisma.order.update({ where: { id: order.id }, data: mapped });
      else {
        order = await this.prisma.order.create({
          data: { companyId, marketplace: 'meesho', marketplaceOrderId: oid, ...mapped },
        });
        imported++;
      }

      const orderItems = Array.isArray(item.items) ? item.items : Array.isArray(item.orderItems) ? item.orderItems : [];
      for (const product of orderItems) {
        const sku = String(product.sku ?? product.skuId ?? product.productSku ?? product.id ?? oid);
        const qty = Number(product.quantity ?? product.qty ?? 1) || 1;
        const old = await this.prisma.orderItem.findFirst({ where: { orderId: order.id, sku } });
        const data: any = { name: product.name ?? product.title ?? sku, qty, barcode: product.barcode ?? null, metadata: product };
        if (old) await this.prisma.orderItem.update({ where: { id: old.id }, data });
        else await this.prisma.orderItem.create({ data: { orderId: order.id, sku, ...data } });
      }
    }

    await this.prisma.marketplaceConnection.update({ where: { id: connectionId }, data: { lastSyncAt: new Date(), status: 'connected' } });
    return { provider: 'meesho', companyId, sellerId, imported, received: items.length, status: 'completed' };
  }

  private extractMeeshoOrders(body: any): any[] {
    if (Array.isArray(body)) return body;
    if (Array.isArray(body.orders)) return body.orders;
    if (Array.isArray(body.data)) return body.data;
    if (Array.isArray(body.data?.orders)) return body.data.orders;
    if (Array.isArray(body.result)) return body.result;
    if (Array.isArray(body.results)) return body.results;
    return [];
  }

  private async syncFlipkart(companyId: string, connectionId: string, token: string) {
    const r = await fetch('https://api.flipkart.net/sellers/v2/orders/search', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ filter: {}, sort: { field: 'orderDate', order: 'desc' }, pageSize: 20 }),
    });
    if (!r.ok) throw new BadRequestException(`Flipkart order sync failed (${r.status})`);
    const b: any = await r.json();
    const items: any[] = b?.orderItems || b?.orderitems || b?.orders || [];
    let imported = 0;
    for (const i of items) {
      const oid = String(i.orderId ?? i.orderID ?? i.orderItemId ?? '');
      if (!oid) continue;
      let order = await this.prisma.order.findFirst({ where: { companyId, marketplace: 'flipkart', marketplaceOrderId: oid } });
      if (order) order = await this.prisma.order.update({ where: { id: order.id }, data: { status: this.mapStatus(i.status ?? i.state), metadata: i } as any });
      else {
        order = await this.prisma.order.create({ data: { companyId, marketplace: 'flipkart', marketplaceOrderId: oid, status: this.mapStatus(i.status ?? i.state), customerName: i.customerName ?? i.buyerName, shippingAddress: i.shippingAddress ?? undefined, awb: i.trackingId ?? i.awb, courier: i.courierName ?? undefined, metadata: i } as any });
        imported++;
      }
      const sku = String(i.sku ?? i.skuId ?? i.listingId ?? oid);
      const qty = Number(i.quantity ?? 1) || 1;
      const old = await this.prisma.orderItem.findFirst({ where: { orderId: order.id, sku } });
      if (old) await this.prisma.orderItem.update({ where: { id: old.id }, data: { name: i.title ?? sku, qty, barcode: i.barcode ?? null, metadata: i } });
      else await this.prisma.orderItem.create({ data: { orderId: order.id, sku, name: i.title ?? sku, qty, barcode: i.barcode ?? null, metadata: i } });
    }
    await this.prisma.marketplaceConnection.update({ where: { id: connectionId }, data: { lastSyncAt: new Date(), status: 'connected' } });
    return { provider: 'flipkart', companyId, imported, received: items.length, status: 'completed' };
  }

  private mapAmazonStatus(s: any): any {
    const x = String(s ?? '').toUpperCase();
    if (['CANCELED', 'UNFULFILLABLE', 'PENDING_AVAILABILITY'].includes(x)) return x === 'CANCELED' ? 'closed' : 'queued';
    if (['SHIPPED', 'PARTIALLY_SHIPPED'].includes(x)) return 'shipped';
    if (['DELIVERED'].includes(x)) return 'closed';
    if (['PENDING', 'PENDING_AVAILABILITY'].includes(x)) return 'queued';
    if (['UNSHIPPED', 'INVOICE_UNCONFIRMED'].includes(x)) return 'packing';
    return 'synced';
  }

  private mapStatus(s: any): any {
    const x = String(s ?? '').toLowerCase();
    if (x.includes('cancel')) return 'closed';
    if (x.includes('deliver')) return 'closed';
    if (x.includes('ship')) return 'shipped';
    if (x.includes('pack')) return 'packing';
    return 'synced';
  }

  async handleWebhook(provider: string, body: any, header?: string) {
    if (!header) throw new UnauthorizedException('Webhook signature is required');
    const connections = await this.prisma.marketplaceConnection.findMany({
      where: { provider: String(provider).toLowerCase() as any, status: 'connected' },
      select: { id: true, companyId: true, webhookSecret: true },
    });
    const raw = JSON.stringify(body ?? {});
    for (const c of connections) {
      const secret = this.crypto.decrypt(c.webhookSecret);
      if (!secret) continue;
      const expected = createHmac('sha256', secret).update(raw).digest('hex');
      const candidate = header.replace(/^sha256=/, '');
      const a = Buffer.from(candidate, 'utf8');
      const b = Buffer.from(expected, 'utf8');
      const hmacOk = a.length === b.length && timingSafeEqual(a, b);
      if (hmacOk) {
        await this.prisma.marketplaceConnection.update({ where: { id: c.id }, data: { lastSyncAt: new Date() } });
        return { received: true, provider: String(provider).toLowerCase(), companyId: c.companyId, event: body?.event || body?.type || 'unknown', id: body?.id ?? null };
      }
    }
    throw new UnauthorizedException('Invalid webhook signature');
  }
}
