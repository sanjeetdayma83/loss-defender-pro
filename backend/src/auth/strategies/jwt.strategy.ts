import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport'; import { ExtractJwt, Strategy } from 'passport-jwt'; import { ConfigService } from '@nestjs/config'; import { PrismaService } from '../../prisma/prisma.service'; import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy,'jwt') {
 constructor(config:ConfigService,private readonly prisma:PrismaService){super({jwtFromRequest:ExtractJwt.fromAuthHeaderAsBearerToken(),ignoreExpiration:false,secretOrKey:config.get<string>('jwt.accessSecret')??process.env.JWT_ACCESS_SECRET??'dev-access'});}
 async validate(payload:any):Promise<AuthenticatedUser>{if(!payload?.sub||!payload?.jti)throw new UnauthorizedException('Invalid access token');const now=new Date();const revoked=await this.prisma.tokenBlacklist.findFirst({where:{expiresAt:{gt:now},OR:[{jti:payload.jti},{userId:payload.sub,createdAt:{gt:new Date((Number(payload.iat)||0)*1000)}}]}});if(revoked)throw new UnauthorizedException('Access token revoked');return {sub:payload.sub,companyId:payload.companyId,role:payload.role,email:payload.email};}
}
