/** Allowed order status transitions */
export const ORDER_TRANSITIONS: Record<string, string[]> = {
  synced: ['queued', 'packing'],
  queued: ['packing', 'cancelled'],
  packing: ['recording', 'scanned'],
  recording: ['scanned', 'evidence_ready'],
  scanned: ['evidence_ready', 'packing', 'dispatched'],
  evidence_ready: ['dispatched'],
  dispatched: ['shipped', 'claimed', 'returned'],
  shipped: ['closed', 'claimed', 'returned'],
  claimed: ['closed'],
  returned: ['closed'],
  closed: [],
  cancelled: [],
};

export function canTransition(from: string, to: string): boolean {
  return (ORDER_TRANSITIONS[from] || []).includes(to);
}
