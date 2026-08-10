import {
  Injectable, UnauthorizedException, BadRequestException,
  ForbiddenException, NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { EmailService } from '../email/email.service';
import { PrismaService } from '../prisma/prisma.service';
import { CompanyPlan, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { createHash, randomInt, randomBytes } from 'crypto';
import {
  RegisterDto, LoginDto, ForgotPasswordDto, ResetPasswordDto,
  VerifyEmailDto, RefreshDto, LogoutDto,
} from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly emailService: EmailService,
  ) {}

  private hashToken(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }

  private async signAccess(payload: {
    sub: string; email: string; companyId: string; role: string;
  }) {
    return this.jwt.signAsync(payload, {
      secret:
        this.config.get<string>('jwt.accessSecret') ??
        process.env.JWT_ACCESS_SECRET ??
        'dev-access',
      expiresIn:
        this.config.get<string>('jwt.accessExpiresIn') ?? '15m',
    } as any);
  }

  private async issueRefresh(
    userId: string, deviceId?: string, ua?: string, ip?: string,
  ) {
    const raw = randomBytes(48).toString('hex');
    const tokenHash = this.hashToken(raw);
    const expiresAt = new Date(Date.now() + 7 * 864e5);
    await this.prisma.refreshSession.create({
      data: { userId, tokenHash, deviceId, userAgent: ua, ipAddress: ip, expiresAt },
    });
    return raw;
  }

  private otpCode() {
    return String(randomInt(100000, 999999));
  }

  private defaultPlan(): CompanyPlan {
    // pick a valid enum member — adjust if your enum differs
    const plans = Object.values(CompanyPlan);
    if (plans.includes('starter' as CompanyPlan)) return 'starter' as CompanyPlan;
    if (plans.includes('free' as CompanyPlan)) return 'free' as CompanyPlan;
    if (plans.includes('professional' as CompanyPlan)) return 'professional' as CompanyPlan;
    return plans[0];
  }

  async register(dto: RegisterDto, ip?: string) {
    const exists = await this.prisma.user.findFirst({ where: { email: dto.email } });
    if (exists) throw new BadRequestException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const company = await this.prisma.company.create({
      data: {
        companyName: dto.companyName,
        email: dto.email,
        phone: dto.phone ?? '',
        status: 'active',
        plan: 'free' as any,
      } as any,
    });

    const user = await this.prisma.user.create({
      data: {
        companyId: company.id,
        email: dto.email,
        name: dto.name,
        phone: dto.phone ?? '',
        role: 'owner',
        passwordHash,
        status: 'pending',
      } as any,
    });

    const code = this.otpCode();
    await this.prisma.authOtp.create({
      data: {
        email: dto.email,
        code,
        purpose: 'verify_email',
        expiresAt: new Date(Date.now() + 15 * 60 * 1000),
      },
    });
    try {
      await this.emailService.sendPasswordResetOtp(dto.email, code);
    } catch (e: any) {
      console.error('[register] email send failed (non-fatal):', e?.message || e);
    }

    return {
      message: 'Registered. Verify email to activate.',
      email: user.email,
      companyId: company.id,
      requiresVerification: true,
      ...(process.env.NODE_ENV !== 'production' ? { devCode: code } : {}),
    };
  }

  private async tokensFor(
    user: { id: string; email: string; companyId: string; role: string },
    deviceId?: string, ip?: string, ua?: string,
  ) {
    const accessToken = await this.signAccess({
      sub: user.id, email: user.email, companyId: user.companyId, role: user.role,
    });
    const refreshToken = await this.issueRefresh(user.id, deviceId, ua, ip);
    return { accessToken, refreshToken };
  }

  async login(dto: LoginDto, ip?: string, ua?: string) {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, status: { not: 'deleted' } },
    });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const lockedUntil = (user as any).lockedUntil as Date | null | undefined;
    if (lockedUntil && lockedUntil > new Date()) {
      throw new ForbiddenException(`Account locked until ${lockedUntil.toISOString()}`);
    }

    const ok = await bcrypt.compare(dto.password, (user as any).passwordHash);
    if (!ok) {
      const fails = (((user as any).failedLoginCount as number) ?? 0) + 1;
      const data: any = { failedLoginCount: fails };
      if (fails >= 5) {
        data.lockedUntil = new Date(Date.now() + 30 * 60 * 1000);
        data.failedLoginCount = 0;
      }
      await this.prisma.user.update({ where: { id: user.id }, data });
      throw new UnauthorizedException('Invalid credentials');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
      } as any,
    });

    if (String((user as any).status) === 'pending') {
      throw new UnauthorizedException('Email not verified');
    }
    if (String((user as any).status) !== 'active') {
      throw new UnauthorizedException('Account not active');
    }
    const tokens = await this.tokensFor(user as any, dto.deviceId, ip, ua);
    return {
      ...tokens,
      user: {
        id: user.id, email: user.email, name: user.name,
        role: user.role, companyId: user.companyId,
      },
    };
  }

  async refresh(dto: RefreshDto, ip?: string, ua?: string) {
    const tokenHash = this.hashToken(dto.refreshToken);
    const session = await this.prisma.refreshSession.findFirst({
      where: { tokenHash, revokedAt: null },
      include: { user: true },
    });
    if (!session || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    if (session.user.status === 'deleted' || session.user.status === 'suspended') {
      throw new ForbiddenException('User disabled');
    }

    if (session.deviceId && dto.deviceId && session.deviceId !== dto.deviceId) {
      throw new UnauthorizedException('Device mismatch');
    }

    await this.prisma.refreshSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });

    return this.tokensFor(session.user as any, dto.deviceId ?? session.deviceId ?? undefined, ip, ua);
  }

  async logout(userId: string, dto: LogoutDto) {
    if (dto.refreshToken) {
      const tokenHash = this.hashToken(dto.refreshToken);
      await this.prisma.refreshSession.updateMany({
        where: { userId, tokenHash, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else if (dto.deviceId) {
      await this.prisma.refreshSession.updateMany({
        where: { userId, deviceId: dto.deviceId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else {
      await this.prisma.refreshSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return { ok: true };
  }

  async sessions(userId: string) {
    return this.prisma.refreshSession.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      select: {
        id: true, deviceId: true, userAgent: true, ipAddress: true,
        expiresAt: true, createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async revokeSession(userId: string, sessionId: string) {
    await this.prisma.refreshSession.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const user = await this.prisma.user.findFirst({ where: { email: dto.email } });
    if (user) {
      const code = this.otpCode();
      await this.prisma.authOtp.create({
        data: {
          email: dto.email,
          code,
          purpose: 'reset_password',
          expiresAt: new Date(Date.now() + 15 * 60 * 1000),
        },
      });
      try {
      await this.emailService.sendPasswordResetOtp(dto.email, code);
    } catch (e: any) {
      console.error('[register] email send failed (non-fatal):', e?.message || e);
    }
      return { ok: true };
    }
    return { ok: true };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const otp = await this.prisma.authOtp.findFirst({
      where: {
        email: dto.email,
        purpose: 'reset_password',
        code: dto.code,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw new BadRequestException('Invalid or expired code');

    const user = await this.prisma.user.findFirst({ where: { email: dto.email } });
    if (!user) throw new NotFoundException('User not found');

    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash, failedLoginCount: 0, lockedUntil: null } as any,
    });
    await this.prisma.authOtp.update({
      where: { id: otp.id },
      data: { usedAt: new Date() },
    });
    await this.prisma.refreshSession.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  async verifyEmail(dto: VerifyEmailDto) {
    const otp = await this.prisma.authOtp.findFirst({
      where: {
        email: dto.email,
        purpose: 'verify_email',
        code: dto.code,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw new BadRequestException('Invalid or expired code');

    await this.prisma.user.updateMany({
      where: { email: dto.email },
      data: { emailVerifiedAt: new Date(), status: 'active' } as any,
    });
    await this.prisma.authOtp.update({
      where: { id: otp.id },
      data: { usedAt: new Date() },
    });
    return { ok: true };
  }
  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await this.prisma.user.findFirst({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    const ok = await bcrypt.compare(currentPassword, (user as any).passwordHash);
    if (!ok) throw new UnauthorizedException('Current password incorrect');
    const passwordHash = await bcrypt.hash(newPassword, 12);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash } as any,
    });
    await this.prisma.refreshSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }
  async listSessions(userId: string) {
    // Support both Session and refreshSession table names
    const client = this.prisma as any;
    if (client.refreshSession) {
      return client.refreshSession.findMany({
        where: { userId, revokedAt: null },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          deviceId: true,
          userAgent: true,
          ipAddress: true,
          createdAt: true,
          expiresAt: true,
        },
      });
    }
    if (client.session) {
      return client.session.findMany({
        where: { userId, revokedAt: null },
        orderBy: { createdAt: 'desc' },
      });
    }
    return [];
  }

  async logoutAll(userId: string) {
    const client = this.prisma as any;
    if (client.refreshSession) {
      await client.refreshSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else if (client.session) {
      await client.session.updateMany({
        where: { userId },
        data: { revokedAt: new Date() },
      });
    }
    return { ok: true };
  }
  async acceptInvite(dto: { token: string; name: string; password: string }) {
    const tokenHash = createHash('sha256').update(dto.token).digest('hex');
    const inv = await this.prisma.inviteToken.findFirst({
      where: {
        tokenHash,
        usedAt: null,
        expiresAt: { gt: new Date() },
      } as any,
    });
    if (!inv) throw new BadRequestException('Invalid or expired invite');

    const passwordHash = await bcrypt.hash(dto.password, 12);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: (inv as any).userId },
        data: {
          passwordHash,
          name: dto.name,
          status: 'active',
          emailVerifiedAt: new Date(),
        } as any,
      }),
      this.prisma.inviteToken.update({
        where: { id: (inv as any).id },
        data: { usedAt: new Date() } as any,
      }),
    ]);
    return { ok: true };
  }
  async revokeAllSessions(userId: string) {
    try {
      await this.prisma.refreshSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } catch (_) {
      await this.prisma.session.updateMany({
        where: { userId },
        data: { revokedAt: new Date() } as any,
      }).catch(() => null);
    }
    return { revoked: true };
  }
}