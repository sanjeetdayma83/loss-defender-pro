// Feature Flags for Loss Defender Pro
// Enable/disable incomplete or experimental features

export const featureFlags = {
  // Billing & Payments
  billing: {
    enabled: false, // Razorpay integration incomplete
    reason: 'Razorpay keys not configured; checkout returns mock orders',
  },
  
  // Marketplace Integrations
  marketplace: {
    amazon: { enabled: false, reason: 'SP-API not implemented' },
    flipkart: { enabled: false, reason: 'Seller API not implemented' },
    meesho: { enabled: false, reason: 'Supplier sync not implemented' },
    shopify: { enabled: false, reason: 'Store sync not implemented' },
    woocommerce: { enabled: false, reason: 'Store sync not implemented' },
  },
  
  // OAuth Providers
  oauth: {
    google: { enabled: false, reason: 'Not production-ready; PKCE + state required' },
    microsoft: { enabled: false, reason: 'Not implemented' },
  },
  
  // Advanced Features
  advancedAnalytics: { enabled: false, reason: 'Custom reports not implemented' },
  apiAccess: { enabled: false, reason: 'API keys & webhooks not implemented' },
  customReports: { enabled: false, reason: 'Report builder not implemented' },
  dataExport: { enabled: false, reason: 'Export functionality not implemented' },
  auditLogsFull: { enabled: true, reason: 'Basic audit logging available' },
  
  // Real-time Features
  supervisorWebSocket: { enabled: true, reason: 'Basic supervisor floor implemented' },
  realtimeNotifications: { enabled: false, reason: 'Push notifications not implemented' },
  
  // AI/ML Features
  ffmpegFrameExtraction: { enabled: false, reason: 'FFmpeg worker not deployed; stub only' },
  aiAnomalyDetection: { enabled: false, reason: 'Not implemented' },
  predictiveAnalytics: { enabled: false, reason: 'Not implemented' },
  
  // Mobile App Features
  pushNotifications: { enabled: false, reason: 'FCM/APNs not configured' },
  offlineMode: { enabled: true, reason: 'Basic offline queue implemented' },
  backgroundSync: { enabled: true, reason: 'Background sync queue implemented' },
  
  // Advanced Settings
  customRoles: { enabled: false, reason: 'Role builder not implemented' },
  workflowAutomation: { enabled: false, reason: 'Automation rules not implemented' },
  sso: { enabled: false, reason: 'SAML/OIDC not implemented' },
  
  // Experimental
  betaFeatures: { enabled: false, reason: 'Beta program not launched' },
};

// Helper to check if a feature is enabled
export function isFeatureEnabled(featurePath: string): boolean {
  const keys = featurePath.split('.');
  let current: any = featureFlags;
  
  for (const key of keys) {
    if (current && typeof current === 'object' && key in current) {
      current = current[key];
    } else {
      return false;
    }
  }
  
  return current === true || (current && current.enabled === true);
}

// Get feature info
export function getFeatureInfo(featurePath: string): { enabled: boolean; reason?: string } | null {
  const keys = featurePath.split('.');
  let current: any = featureFlags;
  
  for (const key of keys) {
    if (current && typeof current === 'object' && key in current) {
      current = current[key];
    } else {
      return null;
    }
  }
  
  if (current === true || (current && current.enabled === true)) {
    return { enabled: true, reason: current?.reason };
  }
  
  return { enabled: false, reason: current?.reason || 'Feature disabled' };
}

// Get all enabled features
export function getEnabledFeatures(): string[] {
  const enabled: string[] = [];
  
  function traverse(obj: any, path: string = '') {
    for (const [key, value] of Object.entries(obj)) {
      const currentPath = path ? `${path}.${key}` : key;
      
      if (value === true || (value && typeof value === 'object' && value.enabled === true)) {
        enabled.push(currentPath);
      } else if (value && typeof value === 'object' && !value.enabled) {
        traverse(value, currentPath);
      }
    }
  }
  
  traverse(featureFlags);
  return enabled;
}