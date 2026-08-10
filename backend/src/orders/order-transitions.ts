/** Allowed order status transitions (doc-aligned subset) */
export const ORDER_TRANSITIONS: Record<string, string[]> = {
  synced: ['queued', 'packing'],
  queued: ['packing', 'cancelled'],
  packing: ['recording', 'scanned'],
  recording: ['scanned', 'evidence_ready'],
  scanned: ['dispatched', 'evidence_ready'],
  evidence_ready: ['dispatched'],
  dispatched: [],
  cancelled: [],
};

export function canTransition(from: string, to: string): boolean {
  return (ORDER_TRANSITIONS[from] || []).includes(to);
}
