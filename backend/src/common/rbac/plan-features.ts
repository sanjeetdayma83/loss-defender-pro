import { planById, PLANS } from '../../billing/plans.catalog';

/** Features gated by subscription plan (docs + pricing sheet) */
export type PlanFeature =
  | 'core'
  | 'claims_returns'
  | 'advanced_dashboard'
  | 'bulk_scan'
  | 'api_access'
  | 'advanced_analytics'
  | 'audit_export'
  | 'rbac_fine'
  | 'priority_support';

const PLAN_FEATURES: Record<string, PlanFeature[]> = {
  free: ['core'],
  starter: ['core'],
  growth: ['core', 'claims_returns', 'advanced_dashboard', 'bulk_scan'],
  enterprise: [
    'core',
    'claims_returns',
    'advanced_dashboard',
    'bulk_scan',
    'api_access',
    'advanced_analytics',
    'audit_export',
    'rbac_fine',
    'priority_support',
  ],
};

export function featuresForPlan(planId: string): PlanFeature[] {
  const id = (planId || 'starter').toLowerCase();
  return PLAN_FEATURES[id] || PLAN_FEATURES.starter;
}

export function planAllows(planId: string, feature: PlanFeature): boolean {
  return featuresForPlan(planId).includes(feature);
}

export function limitsForCompanyPlan(planId: string) {
  const p = planById(planId) || planById('starter') || PLANS[0];
  return {
    planId: p.id,
    warehouseLimit: p.warehouseLimit,
    userLimit: p.userLimit,
    scans: p.scans,
    validityDays: p.validityDays,
    videoRetentionDays: p.videoRetentionDays,
    features: featuresForPlan(p.id),
  };
}
