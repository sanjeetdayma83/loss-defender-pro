import { Role } from '@prisma/client';

export type Permission =
  | 'company.read' | 'company.write'
  | 'users.read' | 'users.write'
  | 'warehouse.read' | 'warehouse.write'
  | 'orders.read' | 'orders.write'
  | 'scanner.use' | 'recording.use'
  | 'evidence.read' | 'evidence.write'
  | 'claims.read' | 'claims.write'
  | 'returns.read' | 'returns.write'
  | 'marketplace.read' | 'marketplace.write'
  | 'billing.read' | 'billing.write'
  | 'audit.read' | 'analytics.read';

const all: Permission[] = [
  'company.read','company.write','users.read','users.write','warehouse.read','warehouse.write','orders.read','orders.write','scanner.use','recording.use','evidence.read','evidence.write','claims.read','claims.write','returns.read','returns.write','marketplace.read','marketplace.write','billing.read','billing.write','audit.read','analytics.read',
];

export const PERMISSIONS: Record<Role, Permission[]> = {
  super_admin: all,
  owner: all,
  manager: all.filter((p) => !['billing.write'].includes(p)),
  supervisor: ['company.read','users.read','warehouse.read','warehouse.write','orders.read','orders.write','scanner.use','recording.use','evidence.read','evidence.write','claims.read','claims.write','returns.read','returns.write','analytics.read'],
  packing_operator: ['warehouse.read','orders.read','orders.write','scanner.use','recording.use','evidence.read'],
  qc_operator: ['warehouse.read','orders.read','scanner.use','evidence.read','evidence.write'],
  claims_executive: ['orders.read','evidence.read','claims.read','claims.write','returns.read','returns.write','analytics.read'],
  marketplace_manager: ['orders.read','orders.write','marketplace.read','marketplace.write','analytics.read'],
  viewer: ['company.read','warehouse.read','orders.read','evidence.read','claims.read','returns.read','analytics.read'],
  auditor: ['company.read','users.read','warehouse.read','orders.read','evidence.read','claims.read','returns.read','marketplace.read','audit.read','analytics.read'],
};

export function hasPermission(role: Role, permission: Permission) {
  return PERMISSIONS[role]?.includes(permission) ?? false;
}
