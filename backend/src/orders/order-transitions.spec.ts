import { canTransition, ORDER_TRANSITIONS } from './order-transitions';

describe('order transitions', () => {
  it('packing → recording allowed', () => {
    expect(canTransition('packing', 'recording')).toBe(true);
  });
  it('dispatched is terminal', () => {
    expect(ORDER_TRANSITIONS.dispatched).toEqual([]);
  });
  it('evidence_ready → packing blocked', () => {
    expect(canTransition('evidence_ready', 'packing')).toBe(false);
  });
});
