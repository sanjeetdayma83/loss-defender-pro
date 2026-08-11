import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import * as crypto from 'crypto';
import { PLANS, SCAN_PACKS, RETENTION_ADDONS, planById } from './plans.catalog';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RazorpayService {
  private readonly log = new Logger(RazorpayService.name);

  configured() {
    const key = process.env.RAZORPAY_KEY_ID || '';
    const secret = process.env.RAZORPAY_KEY_SECRET || '';
    return !!(key && secret && !key.includes('PLACE') && !secret.includes('PLACE'));
  }

  /** Create order — real API when keys set; else mock order id for UI test */
  async createOrder(amountInr: number, receipt: string, notes: Record<string, string>) {
    const amountPaise = Math.round(amountInr * 100);
    if (!this.configured()) {
      return {
        configured: false,
        id: `order_mock_${Date.now()}`,
        amount: amountPaise,
        currency: 'INR',
        receipt,
        notes,
        keyId: null,
        message: 'Set RAZORPAY_KEY_ID + RAZORPAY_KEY_SECRET',
      };
    }
    const keyId = process.env.RAZORPAY_KEY_ID!;
    const keySecret = process.env.RAZORPAY_KEY_SECRET!;
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    const res = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: 'INR',
        receipt,
        notes,
      }),
    });
    if (!res.ok) {
      const t = await res.text();
      this.log.error(`Razorpay order failed: ${t}`);
      throw new BadRequestException('Razorpay order create failed');
    }
    const data = (await res.json()) as any;
    return { configured: true, ...data, keyId };
  }

  verifyPaymentSignature(orderId: string, paymentId: string, signature: string) {
    if (!this.configured()) {
      return { verified: true, mode: 'mock' as const };
    }
    const secret = process.env.RAZORPAY_KEY_SECRET!;
    const body = `${orderId}|${paymentId}`;
    const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
    const ok = expected === signature;
    return { verified: ok, mode: 'live' as const };
  }
}

@Injectable()
export class BillingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
  ) {}

  catalog() {
    return {
      plans: PLANS,
      scanPacks: SCAN_PACKS,
      retentionAddons: RETENTION_ADDONS,
      currency: 'INR',
      gstNote: 'Prices inclusive of 18% GST (as marketed)',
      razorpayConfigured: this.razorpay.configured(),
    };
  }

  async subscription(companyId: string) {
    const c = await this.prisma.company.findFirst({ where: { id: companyId } });
    return {
      plan: (c as any)?.plan || 'free',
      storageUsed: String((c as any)?.storageUsed ?? 0),
      storageQuota: String((c as any)?.storageQuota ?? 0),
      scanQuota: (c as any)?.scanQuota ?? null,
      scanUsed: (c as any)?.scanUsed ?? null,
      planExpiresAt: (c as any)?.planExpiresAt ?? null,
      razorpayConfigured: this.razorpay.configured(),
    };
  }

  async createSubscriptionOrder(companyId: string, planId: string) {
    const plan = planById(planId);
    if (!plan) throw new BadRequestException('Unknown plan');
    const order = await this.razorpay.createOrder(plan.priceInr, `plan_${planId}_${companyId.slice(0, 8)}`, {
      companyId,
      planId,
      type: 'subscription',
    });
    return { plan, order };
  }

  async verifyAndActivate(
    companyId: string,
    body: { planId: string; razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string },
  ) {
    const plan = planById(body.planId);
    if (!plan) throw new BadRequestException('Unknown plan');
    const v = this.razorpay.verifyPaymentSignature(
      body.razorpay_order_id,
      body.razorpay_payment_id,
      body.razorpay_signature,
    );
    if (!v.verified) throw new BadRequestException('Invalid payment signature');

    const expires = new Date();
    expires.setDate(expires.getDate() + plan.validityDays);

    const c = await this.prisma.company.update({
      where: { id: companyId },
      data: {
        plan: plan.id as any,
        storageQuota: BigInt(200 * 1024 ** 3) as any, // soft default
        // optional fields if schema has them:
        // scanQuota: plan.scans, planExpiresAt: expires,
      } as any,
    });

    return {
      verified: true,
      mode: v.mode,
      plan: plan.id,
      companyId,
      expiresAt: expires.toISOString(),
      company: { id: c.id, plan: (c as any).plan },
    };
  }

  async createScanPackOrder(companyId: string, packId: string) {
    const pack = SCAN_PACKS.find((p) => p.id === packId);
    if (!pack) throw new BadRequestException('Unknown pack');
    const order = await this.razorpay.createOrder(pack.priceInr, `pack_${packId}_${Date.now()}`, {
      companyId,
      packId,
      type: 'scan_pack',
    });
    return { pack, order };
  }
}
