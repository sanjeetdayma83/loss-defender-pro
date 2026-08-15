import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized status badge widget for consistent status display across the app.
/// Uses color-blind safe palette per design specs.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;
  final bool showIcon;

  const StatusBadge({
    super.key,
    required this.status,
    this.small = false,
    this.showIcon = false,
  });

  /// Map of status to color and label - single source of truth
  static const Map<String, _StatusConfig> _config = {
    // Order statuses
    'synced': _StatusConfig(Color(0xFFF59E0B), 'Synced'),
    'queued': _StatusConfig(Color(0xFFF59E0B), 'Queued'),
    'pending': _StatusConfig(Color(0xFFF59E0B), 'Pending'),
    'packing': _StatusConfig(Color(0xFFF59E0B), 'Packing'),
    'recording': _StatusConfig(Color(0xFF3B82F6), 'Recording'),
    'scanned': _StatusConfig(Color(0xFF22C55E), 'Scanned'),
    'evidence_ready': _StatusConfig(Color(0xFF8B5CF6), 'Evidence Ready'),
    'dispatched': _StatusConfig(Color(0xFF22C55E), 'Dispatched'),
    'shipped': _StatusConfig(Color(0xFF22C55E), 'Shipped'),
    'closed': _StatusConfig(Color(0xFF22C55E), 'Closed'),
    'verified': _StatusConfig(Color(0xFF22C55E), 'Verified'),
    'claimed': _StatusConfig(Color(0xFFEF4444), 'Claimed'),
    'returned': _StatusConfig(Color(0xFFEF4444), 'Returned'),
    'failed': _StatusConfig(Color(0xFFEF4444), 'Failed'),
    'exception': _StatusConfig(Color(0xFFEF4444), 'Exception'),

    // Return statuses
    'requested': _StatusConfig(Color(0xFFF59E0B), 'Requested'),
    'received': _StatusConfig(Color(0xFF3B82F6), 'Received'),
    'inspecting': _StatusConfig(Color(0xFF3B82F6), 'Inspecting'),
    'refunded': _StatusConfig(Color(0xFF22C55E), 'Refunded'),
    'restocked': _StatusConfig(Color(0xFF22C55E), 'Restocked'),
    'rejected': _StatusConfig(Color(0xFFEF4444), 'Rejected'),

    // Claim statuses
    'open': _StatusConfig(Color(0xFFF59E0B), 'Open'),
    'under_review': _StatusConfig(Color(0xFF3B82F6), 'Under Review'),
    'approved': _StatusConfig(Color(0xFF22C55E), 'Approved'),

    // Evidence/Recording statuses
    'started': _StatusConfig(Color(0xFF3B82F6), 'Started'),
    'processed': _StatusConfig(Color(0xFF8B5CF6), 'Processed'),
    'uploading': _StatusConfig(Color(0xFFF59E0B), 'Uploading'),
    'completed': _StatusConfig(Color(0xFF22C55E), 'Completed'),

    // Generic
    'active': _StatusConfig(Color(0xFF22C55E), 'Active'),
    'inactive': _StatusConfig(Color(0xFF64748B), 'Inactive'),
    'invited': _StatusConfig(Color(0xFFF59E0B), 'Invited'),
    'disabled': _StatusConfig(Color(0xFFEF4444), 'Disabled'),
  };

  static _StatusConfig _getConfig(String status) {
    final normalized = status.toLowerCase().trim();
    return _config[normalized] ??
        _StatusConfig(AppColors.accent, _humanize(status));
  }

  static String _humanize(String s) {
    return s
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    final fontSize = small ? 10.0 : 11.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getIcon(config.color),
              size: small ? 10 : 12,
              color: config.color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            config.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(Color color) {
    if (color == const Color(0xFF22C55E)) return Icons.check_circle;
    if (color == const Color(0xFFEF4444)) return Icons.error;
    if (color == const Color(0xFFF59E0B)) return Icons.hourglass_empty;
    if (color == const Color(0xFF3B82F6)) return Icons.info;
    if (color == const Color(0xFF8B5CF6)) return Icons.verified;
    if (color == const Color(0xFF06B6D4)) return Icons.photo_library;
    return Icons.help_outline;
  }
}

class _StatusConfig {
  final Color color;
  final String label;

  const _StatusConfig(this.color, this.label);
}

/// Extension for easy status badge creation
extension StatusBadgeExtension on String {
  Widget toStatusBadge({bool small = false, bool showIcon = false}) {
    return StatusBadge(status: this, small: small, showIcon: showIcon);
  }
}