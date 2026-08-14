import { canTransition, ORDER_TRANSITIONS } from './order-transitions';

describe('order transitions', () => {
  it('packing → recording allowed', () => {
    expect(canTransition('packing', 'recording')).toBe(true);
  });
  it('dispatched can transition to shipped/claimed/returned', () => {
    expect(ORDER_TRANSITIONS.dispatched).toEqual(['shipped', 'claimed', 'returned']);
  });
  it('evidence_ready → packing blocked', () => {
    expect(canTransition('evidence_ready', 'packing')).toBe(false);
  });
});
