import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { PERMISSION_KEY } from '../decorators/permissions.decorator';
import { hasPermission, Permission } from './permission-matrix';

@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}
  canActivate(context: ExecutionContext) {
    const permission = this.reflector.getAllAndOverride<Permission>(PERMISSION_KEY, [context.getHandler(), context.getClass()]);
    if (!permission) return true;
    const user = context.switchToHttp().getRequest().user;
    if (!user?.role || !hasPermission(user.role as Role, permission)) throw new ForbiddenException(`Permission denied: ${permission}`);
    return true;
  }
}
