export type AppRole =
  | 'owner'
  | 'admin'
  | 'warehouse_manager'
  | 'supervisor'
  | 'packing_operator'
  | 'viewer';

export const ROLE_PERMISSIONS: Record<AppRole, string[]> = {
  owner: [
    'order.read', 'order.write', 'order.dispatch',
    'scan.execute', 'recording.execute', 'evidence.read', 'evidence.export',
    'claim.manage', 'return.manage',
    'user.invite', 'user.manage', 'warehouse.manage',
    'settings.manage', 'analytics.read', 'billing.manage',
    'marketplace.manage', 'audit.read',
  ],
  admin: [
    'order.read', 'order.write', 'order.dispatch',
    'scan.execute', 'recording.execute', 'evidence.read', 'evidence.export',
    'claim.manage', 'return.manage',
    'user.invite', 'warehouse.manage',
    'settings.manage', 'analytics.read', 'billing.manage',
    'marketplace.manage', 'audit.read',
  ],
  warehouse_manager: [
    'order.read', 'order.write', 'order.dispatch',
    'scan.execute', 'recording.execute', 'evidence.read',
    'claim.manage', 'return.manage',
    'user.invite', 'warehouse.manage',
    'analytics.read',
  ],
  supervisor: [
    'order.read', 'order.dispatch',
    'scan.execute', 'recording.execute', 'evidence.read',
    'claim.manage', 'return.manage',
    'analytics.read',
  ],
  packing_operator: [
    'order.read', 'scan.execute', 'recording.execute', 'evidence.read',
  ],
  viewer: [
    'order.read', 'evidence.read', 'analytics.read',
  ],
};

export function permissionsFor(role: string): string[] {
  const r = (role || 'packing_operator') as AppRole;
  return ROLE_PERMISSIONS[r] || ROLE_PERMISSIONS.packing_operator;
}

export function can(role: string, permission: string): boolean {
  return permissionsFor(role).includes(permission);
}

/** Map UI routes → required permission */
export const ROUTE_PERMISSION: Record<string, string> = {
  '/dashboard': 'order.read',
  '/orders': 'order.read',
  '/scanner': 'scan.execute',
  '/recording': 'recording.execute',
  '/dispatch': 'order.dispatch',
  '/evidence': 'evidence.read',
  '/claims': 'claim.manage',
  '/returns': 'return.manage',
  '/warehouses': 'warehouse.manage',
  '/users': 'user.invite',
  '/analytics': 'analytics.read',
  '/marketplace': 'marketplace.manage',
  '/billing': 'billing.manage',
  '/settings': 'settings.manage',
  '/alerts': 'order.read',
};
