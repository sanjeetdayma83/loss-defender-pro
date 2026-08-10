import { SetMetadata } from '@nestjs/common';
import { Permission } from '../guards/permission-matrix';
export const PERMISSION_KEY = 'permission';
export const Permission = (permission: Permission) => SetMetadata(PERMISSION_KEY, permission);
