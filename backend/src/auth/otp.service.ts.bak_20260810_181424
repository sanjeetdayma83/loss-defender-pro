import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import { randomInt } from 'crypto';

@Injectable()
export class OtpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
  ) {}

  private code() {
    return String(randomInt(100000, 999999));
  }

  async request(email: string, purpose = 'sensitive') {
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
    const row = await this.prisma.authOtp.findFirst({
      where: { email, purpose, code } as any,
      orderBy: { createdAt: 'desc' },
    });
    if (!row || new Date((row as any).expiresAt) < new Date()) {
      throw new BadRequestException('Invalid or expired OTP');
    }
    try {
      await this.prisma.authOtp.delete({ where: { id: (row as any).id } });
    } catch (_) {}
    return { verified: true, purpose };
  }
}
