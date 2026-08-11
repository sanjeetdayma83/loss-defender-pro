import {
  Injectable, CanActivate, ExecutionContext,
  ForbiddenException, UnauthorizedException, Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class TenantGuard implements CanActivate {
  private readonly logger = new Logger(TenantGuard.name);
  private readonly allowedTenants: Set<string>;

  constructor(
    private readonly reflector: Reflector,
    private readonly config: ConfigService,
  ) {
    // Comma-separated company UUIDs that super_admin may switch into.
    // Empty = super_admin CANNOT switch (safest default for production).
    const raw = this.config.get<string>('SUPER_ADMIN_ALLOWED_TENANTS') || '';
    this.allowedTenants = new Set(
      raw.split(',').map((s) => s.trim()).filter(Boolean),
    );
  }

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
      if (headerTenant) {
        if (this.allowedTenants.size === 0) {
          throw new ForbiddenException(
            'Super-admin tenant switch disabled (SUPER_ADMIN_ALLOWED_TENANTS empty)',
          );
        }
        if (!this.allowedTenants.has(headerTenant)) {
          this.logger.warn(
            `super_admin ${user.sub || user.id} blocked tenant switch → ${headerTenant}`,
          );
          throw new ForbiddenException('Tenant not in super-admin allowlist');
        }
        companyId = headerTenant;
        // Flag for audit interceptors
        request.superAdminTenantSwitch = true;
        request.originalCompanyId = user.companyId;
      }
    }

    if (!companyId) {
      throw new ForbiddenException('Tenant context missing');
    }

    request.tenantId = companyId;
    request.user = { ...user, companyId };
    return true;
  }
}
