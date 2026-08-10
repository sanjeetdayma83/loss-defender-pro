import { Controller, Get } from '@nestjs/common';
import { CurrentUser, AuthenticatedUser } from '../decorators/current-user.decorator';
import { permissionsFor } from './permissions';

@Controller('rbac')
export class RbacController {
  @Get('permissions')
  mine(@CurrentUser() u: AuthenticatedUser) {
    const role = (u as any).role || 'packing_operator';
    return { role, permissions: permissionsFor(role) };
  }
}
