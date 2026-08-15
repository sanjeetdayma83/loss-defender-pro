import { Injectable, UnauthorizedException } from "@nestjs/common";
import { PassportStrategy } from "@nestjs/passport";
import { ExtractJwt, Strategy } from "passport-jwt";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../../prisma/prisma.service";

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, "jwt") {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey:
        config.get<string>("JWT_ACCESS_SECRET") ??
        config.get<string>("jwt.accessSecret"),
    });
  }

  async validate(payload: any) {
    const jti = payload?.jti;
    if (jti) {
      try {
        const hit = await (this.prisma as any).tokenBlacklist.findFirst({
          where: { jti },
        });
        if (hit) throw new UnauthorizedException("Token revoked");
      } catch (e: any) {
        if (e instanceof UnauthorizedException) throw e;
      }
    }
    const userId = payload.sub || payload.userId || payload.id;
    if (!userId) throw new UnauthorizedException();
    let warehouseId: string | null = payload.warehouseId ?? null;
    try {
      const dbUser = await this.prisma.user.findFirst({
        where: { id: userId },
        select: { warehouseId: true, status: true, companyId: true, role: true },
      });
      if (!dbUser || (dbUser as any).status === 'deleted') throw new UnauthorizedException();
      warehouseId = (dbUser as any).warehouseId ?? null;
    } catch (e: any) {
      if (e instanceof UnauthorizedException) throw e;
    }
    return {
      ...payload,
      id: userId,
      sub: userId,
      userId,
      companyId: payload.companyId,
      role: payload.role,
      warehouseId,
    };
  }
}