import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET') || config.get<string>('jwt.accessSecret') || 'dev',
      passReqToCallback: false,
    });
  }

  async validate(payload: any) {
    if (payload?.jti) {
      const bl = await (this.prisma as any).tokenBlacklist?.findFirst?.({
        where: { jti: payload.jti },
      });
      if (bl) throw new UnauthorizedException('Token revoked');
    }
    // Fallback: hash-less tokens — check user status
    const userId = payload.sub || payload.userId;
    if (!userId) throw new UnauthorizedException();
    return {
      ...payload,
      id: userId,
      sub: userId,
      userId,
      companyId: payload.companyId,
      role: payload.role,
    };
  }
}