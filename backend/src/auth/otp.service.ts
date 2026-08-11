import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import { randomInt } from 'crypto';

const REQUEST_COOLDOWN_MS = 60 * 1000; // 1 request per email+purpose per 60s
const MAX_VERIFY_ATTEMPTS = 5;
const LOCKOUT_MS = 15 * 60 * 1000; // 15 min lockout after too many failed verifies

interface AttemptState {
  count: number;
  lockedUntil?: number;
}

@Injectable()
export class OtpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
  ) {}

  // NOTE: in-memory — fine for a single Nest instance. If you scale to
  // multiple instances/pods, move this to Redis (key: email+purpose).
  private failedAttempts = new Map<string, AttemptState>();

  private attemptKey(email: string, purpose: string) {
    return `${email.toLowerCase()}::${purpose}`;
  }

  private code() {
    return String(randomInt(100000, 999999));
  }

  async request(email: string, purpose = 'sensitive') {
    const key = this.attemptKey(email, purpose);
    const state = this.failedAttempts.get(key);
    if (state?.lockedUntil && state.lockedUntil > Date.now()) {
      const waitSec = Math.ceil((state.lockedUntil - Date.now()) / 1000);
      throw new BadRequestException(
        `Too many attempts. Try again in ${waitSec}s.`,
      );
    }

    // Cooldown: don't allow spamming new codes
    const last = await this.prisma.authOtp.findFirst({
      where: { email, purpose } as any,
      orderBy: { createdAt: 'desc' },
    });
    if (
      last &&
      Date.now() - new Date((last as any).createdAt).getTime()  < REQUEST_COOLDOWN_MS
    ) {
      throw new BadRequestException(
        'Please wait a minute before requesting another code.',
      );
    }

    // Invalidate all previously issued, still-unexpired codes for this
    // email+purpose so only the newest code is ever valid.
    await this.prisma.authOtp.deleteMany({
      where: { email, purpose, expiresAt: { gt: new Date() } } as any,
    });

    const code = this.code();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
    await this.prisma.authOtp.create({
      data: { email, code, purpose, expiresAt } as any,
    });
    try {
      await this.email.send(
        email,
        `LDP OTP (${purpose})`,
        `Your code is ${code}. Valid 15 minutes.`,
      );
    } catch (_) {}

    const out: any = { sent: true, purpose, expiresAt };
    if (process.env.NODE_ENV !== 'production') out.devCode = code;
    return out;
  }

  async verify(email: string, purpose: string, code: string) {
    const key = this.attemptKey(email, purpose);
    const state = this.failedAttempts.get(key) ?? { count: 0 };

    if (state.lockedUntil && state.lockedUntil > Date.now()) {
      const waitSec = Math.ceil((state.lockedUntil - Date.now()) / 1000);
      throw new BadRequestException(
        `Too many failed attempts. Try again in ${waitSec}s.`,
      );
    }

    const row = await this.prisma.authOtp.findFirst({
      where: { email, purpose, code } as any,
      orderBy: { createdAt: 'desc' },
    });

    if (!row || new Date((row as any).expiresAt) < new Date()) {
      state.count += 1;
      if (state.count >= MAX_VERIFY_ATTEMPTS) {
        state.lockedUntil = Date.now() + LOCKOUT_MS;
        state.count = 0;
      }
      this.failedAttempts.set(key, state);
      throw new BadRequestException('Invalid or expired OTP');
    }

    // Success — reset attempt tracking and consume the code.
    this.failedAttempts.delete(key);
    try {
      await this.prisma.authOtp.delete({ where: { id: (row as any).id } });
    } catch (_) {}
    return { verified: true, purpose };
  }
}