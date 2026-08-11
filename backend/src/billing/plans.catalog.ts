/** Loss Defender Pro — public pricing (INR, GST inclusive as marketed) */
export const PLANS = [
  {
    id: 'starter',
    name: 'Starter',
    priceInr: 5000,
    intervalMonths: 3,
    pricePerMonthInr: 1667,
    scans: 5100,
    validityDays: 90,
    videoRetentionDays: 30,
    warehouseLimit: 1,
    userLimit: 3,
    features: [
      '5100 scans every 3 months',
      'All core features',
      '1 Warehouse',
      'Up to 3 Users',
      'Standard Email Support',
      'Mobile App + Web Access',
    ],
  },
  {
    id: 'growth',
    name: 'Growth',
    priceInr: 20000,
    intervalMonths: 6,
    pricePerMonthInr: 3333,
    scans: 22200,
    validityDays: 180,
    videoRetentionDays: 30,
    warehouseLimit: 3,
    userLimit: 10,
    features: [
      '22200 scans every 6 months',
      'All Starter features',
      'Up to 3 Warehouses',
      'Up to 10 Users',
      'Advanced Dashboard & Reports',
      'Priority Email & Chat Support',
      'Bulk Upload & Scan',
      'Claims & Returns Management',
    ],
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    priceInr: 45000,
    intervalMonths: 12,
    pricePerMonthInr: 3750,
    scans: 56200,
    validityDays: 365,
    videoRetentionDays: 30,
    warehouseLimit: 9999,
    userLimit: 9999,
    features: [
      '56200 scans every 12 months',
      'All Growth features',
      'Unlimited Warehouses',
      'Unlimited Users',
      'Advanced Analytics & Custom Reports',
      'API Access & Integrations',
      'Dedicated Account Manager',
      'Role Based Access Control',
      'Data Export & Audit Logs',
    ],
  },
] as const;

export const SCAN_PACKS = [
  { id: 'pack_1k', scans: 1000, priceInr: 600 },
  { id: 'pack_2_5k', scans: 2500, priceInr: 1250 },
  { id: 'pack_5k', scans: 5000, priceInr: 2500 },
  { id: 'pack_10k', scans: 10000, priceInr: 4500 },
  { id: 'pack_25k', scans: 25000, priceInr: 10000 },
];

export const RETENTION_ADDONS = [
  { id: 'ret_90', days: 90, pricePerScanInr: 0.15 },
  { id: 'ret_180', days: 180, pricePerScanInr: 0.25 },
  { id: 'ret_365', days: 365, pricePerScanInr: 0.4 },
];

export function planById(id: string) {
  return PLANS.find((p) => p.id === id);
}
