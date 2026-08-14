// Feature Flags for Loss Defender Pro
// Enable/disable incomplete or experimental features

class FeatureFlags {
  // Billing & Payments
  static const Map<String, dynamic> billing = {
    'enabled': false, // Razorpay integration incomplete
    'reason': 'Razorpay keys not configured; checkout returns mock orders',
  };

  // Marketplace Integrations
  static const Map<String, dynamic> marketplace = {
    'amazon': {'enabled': false, 'reason': 'SP-API not implemented'},
    'flipkart': {'enabled': false, 'reason': 'Seller API not implemented'},
    'meesho': {'enabled': false, 'reason': 'Supplier sync not implemented'},
    'shopify': {'enabled': false, 'reason': 'Store sync not implemented'},
    'woocommerce': {'enabled': false, 'reason': 'Store sync not implemented'},
  };

  // OAuth Providers
  static const Map<String, dynamic> oauth = {
    'google': {'enabled': false, 'reason': 'Not production-ready; PKCE + state required'},
    'microsoft': {'enabled': false, 'reason': 'Not implemented'},
  };

  // Advanced Features
  static const Map<String, dynamic> advancedAnalytics = {
    'enabled': false, 'reason': 'Custom reports not implemented',
  };
  static const Map<String, dynamic> apiAccess = {
    'enabled': false, 'reason': 'API keys & webhooks not implemented',
  };
  static const Map<String, dynamic> customReports = {
    'enabled': false, 'reason': 'Report builder not implemented',
  };
  static const Map<String, dynamic> dataExport = {
    'enabled': false, 'reason': 'Export functionality not implemented',
  };
  static const Map<String, dynamic> auditLogsFull = {
    'enabled': true, 'reason': 'Basic audit logging available',
  };

  // Real-time Features
  static const Map<String, dynamic> supervisorWebSocket = {
    'enabled': true, 'reason': 'Basic supervisor floor implemented',
  };
  static const Map<String, dynamic> realtimeNotifications = {
    'enabled': false, 'reason': 'Push notifications not implemented',
  };

  // AI/ML Features
  static const Map<String, dynamic> ffmpegFrameExtraction = {
    'enabled': true, 'reason': 'FFmpeg worker implemented',
  };
  static const Map<String, dynamic> aiAnomalyDetection = {
    'enabled': false, 'reason': 'Not implemented',
  };
  static const Map<String, dynamic> predictiveAnalytics = {
    'enabled': false, 'reason': 'Not implemented',
  };

  // Mobile App Features
  static const Map<String, dynamic> pushNotifications = {
    'enabled': false, 'reason': 'FCM/APNs not configured',
  };
  static const Map<String, dynamic> offlineMode = {
    'enabled': true, 'reason': 'Basic offline queue implemented',
  };
  static const Map<String, dynamic> backgroundSync = {
    'enabled': true, 'reason': 'Background sync queue implemented',
  };

  // Advanced Settings
  static const Map<String, dynamic> customRoles = {
    'enabled': false, 'reason': 'Role builder not implemented',
  };
  static const Map<String, dynamic> workflowAutomation = {
    'enabled': false, 'reason': 'Automation rules not implemented',
  };
  static const Map<String, dynamic> sso = {
    'enabled': false, 'reason': 'SAML/OIDC not implemented',
  };

  // Experimental
  static const Map<String, dynamic> betaFeatures = {
    'enabled': false, 'reason': 'Beta program not launched',
  };

  static const Map<String, dynamic> _allFlags = {
    'billing': billing,
    'marketplace': marketplace,
    'oauth': oauth,
    'advancedAnalytics': advancedAnalytics,
    'apiAccess': apiAccess,
    'customReports': customReports,
    'dataExport': dataExport,
    'auditLogsFull': auditLogsFull,
    'supervisorWebSocket': supervisorWebSocket,
    'realtimeNotifications': realtimeNotifications,
    'ffmpegFrameExtraction': ffmpegFrameExtraction,
    'aiAnomalyDetection': aiAnomalyDetection,
    'predictiveAnalytics': predictiveAnalytics,
    'pushNotifications': pushNotifications,
    'offlineMode': offlineMode,
    'backgroundSync': backgroundSync,
    'customRoles': customRoles,
    'workflowAutomation': workflowAutomation,
    'sso': sso,
    'betaFeatures': betaFeatures,
  };

  // Helper to check if a feature is enabled
  static bool isFeatureEnabled(String featurePath) {
    final keys = featurePath.split('.');
    dynamic current = _allFlags;

    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return false;
      }
    }

    return current == true || (current is Map && current['enabled'] == true);
  }

  // Get feature info
  static Map<String, dynamic>? getFeatureInfo(String featurePath) {
    final keys = featurePath.split('.');
    dynamic current = _allFlags;

    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }

    if (current == true || (current is Map && current['enabled'] == true)) {
      return {'enabled': true, 'reason': current['reason']};
    }

    return {'enabled': false, 'reason': current?['reason'] ?? 'Feature disabled'};
  }

  // Get all enabled features
  static List<String> getEnabledFeatures() {
    final enabled = <String>[];

    void traverse(dynamic obj, String path) {
      if (obj is Map) {
        for (final entry in obj.entries) {
          final currentPath = path.isEmpty ? entry.key : '$path.${entry.key}';
          final value = entry.value;

          if (value == true || (value is Map && value['enabled'] == true)) {
            enabled.add(currentPath);
          } else if (value is Map && value['enabled'] != true) {
            traverse(value, currentPath);
          }
        }
      }
    }

    traverse(_allFlags, '');
    return enabled;
  }
}

// Helper functions for backward compatibility
bool isFeatureEnabled(String featurePath) => FeatureFlags.isFeatureEnabled(featurePath);
Map<String, dynamic>? getFeatureInfo(String featurePath) => FeatureFlags.getFeatureInfo(featurePath);
List<String> getEnabledFeatures() => FeatureFlags.getEnabledFeatures();