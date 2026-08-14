/** Allowed order status transitions (doc-aligned subset) */
export const ORDER_TRANSITIONS: Record<string, string[]> = {
  synced: ['queued', 'packing'],
  queued: ['packing'],
  packing: ['recording', 'scanned'],
  recording: ['scanned'],
  scanned: ['evidence_ready', 'packing'],
  evidence_ready: ['dispatched'],
  dispatched: ['shipped', 'claimed', 'returned'],
  shipped: ['closed', 'claimed', 'returned'],
  claimed: ['closed'],
  returned: ['closed'],
  closed: [],
};

export function canTransition(from: string, to: string): boolean {
  return (ORDER_TRANSITIONS[from] || []).includes(to);
}
