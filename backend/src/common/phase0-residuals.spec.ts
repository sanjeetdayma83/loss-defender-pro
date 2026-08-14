import { canTransition, ORDER_TRANSITIONS } from '../orders/order-transitions';
import { can, permissionsFor } from '../common/rbac/permissions';
import { warehouseScope } from '../common/utils/warehouse-scope';
import { tenantWhere } from '../common/utils/tenant';

describe('phase0 residuals', () => {
  it('tenantWhere always includes companyId', () => {
    const w = tenantWhere('co-1', { id: 'x' }) as { companyId: string; id?: string };
    expect(w.companyId).toBe('co-1');
    expect((w as any).id).toBe('x');
  });

  it('tenantWhere throws without companyId', () => {
    expect(() => tenantWhere('', {})).toThrow();
  });

  it('order state machine blocks illegal jump', () => {
    expect(canTransition('evidence_ready', 'closed')).toBe(false);
    expect(canTransition('packing', 'recording')).toBe(true);
  });

  it('packing_operator cannot user.invite', () => {
    expect(can('packing_operator', 'user.invite')).toBe(false);
    expect(can('owner', 'user.invite')).toBe(true);
  });

  it('warehouseScope filters operators', () => {
    const s = warehouseScope({ role: 'packing_operator', warehouseId: 'wh-1' }, { status: 'packing' });
    expect(s.warehouseId).toBe('wh-1');
    const open = warehouseScope({ role: 'owner', warehouseId: 'wh-1' }, {});
    expect(open.warehouseId).toBeUndefined();
  });

  it('permissionsFor owner includes billing', () => {
    expect(permissionsFor('owner')).toContain('billing.manage');
  });
});
