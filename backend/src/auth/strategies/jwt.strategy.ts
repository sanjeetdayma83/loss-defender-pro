import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('jwt.accessSecret'),
    });
  }

  // Whatever this returns becomes `request.user` — kept minimal on purpose:
  // companyId + role travel in the JWT so most routes never hit the DB just to
  // check tenant/role (see §9.2 JWT Payload in the spec).
  async validate(payload: any): Promise<AuthenticatedUser> {
    return {
      sub: payload.sub,
      companyId: payload.companyId,
      role: payload.role,
      email: payload.email,
    };
  }
}
