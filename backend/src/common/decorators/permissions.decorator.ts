import { SetMetadata } from '@nestjs/common';
import type { Permission as PermissionName } from '../guards/permission-matrix';

export const PERMISSION_KEY = 'permission';

export const Permission = (permission: PermissionName) =>
  SetMetadata(PERMISSION_KEY, permission);
