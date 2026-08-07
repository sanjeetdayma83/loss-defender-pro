import {
  Injectable, CanActivate, ExecutionContext,
  ForbiddenException, UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class TenantGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const user = request.user;
    if (!user) throw new UnauthorizedException('Not authenticated');

    let companyId: string | undefined = user.companyId;
    if (user.role === 'super_admin') {
      const headerTenant = request.headers['x-tenant-id'] as string | undefined;
      if (headerTenant) companyId = headerTenant;
    }
    if (!companyId) {
      throw new ForbiddenException('Tenant context missing');
    }
    request.tenantId = companyId;
    request.user = { ...user, companyId };
    return true;
  }
}
