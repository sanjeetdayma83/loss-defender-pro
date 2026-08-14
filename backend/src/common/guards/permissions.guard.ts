import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { can } from '../rbac/permissions';

export const PERMISSION_KEY = 'permission';

export const RequirePermission = (permission: string) =>
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  require('@nestjs/common').SetMetadata(PERMISSION_KEY, permission);

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const permission = this.reflector.getAllAndOverride<string>(PERMISSION_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!permission) return true;

    const req = ctx.switchToHttp().getRequest();
    const role = req.user?.role || 'packing_operator';
    if (!can(role, permission)) {
      throw new ForbiddenException(`Missing permission: ${permission}`);
    }
    return true;
  }
}
