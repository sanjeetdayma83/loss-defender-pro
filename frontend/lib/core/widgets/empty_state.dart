import 'package:flutter/material.dart';

/// Empty state widget with consistent styling
class EmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Widget? action;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.message,
    this.icon,
    this.action,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ] else if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {}, // Placeholder - parent should provide callback
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Convenience empty states
class EmptyOrders extends StatelessWidget {
  final VoidCallback? onCreate;
  const EmptyOrders({super.key, this.onCreate});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      message: 'No orders yet',
      icon: Icons.receipt_long,
      actionLabel: 'Create Order',
      action: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Create Order'),
      ),
    );
  }
}

class EmptyEvidence extends StatelessWidget {
  const EmptyEvidence({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No evidence packs yet — finish a recording',
      icon: Icons.movie_creation_outlined,
    );
  }
}

class EmptyClaims extends StatelessWidget {
  const EmptyClaims({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No claims yet',
      icon: Icons.gavel,
    );
  }
}

class EmptyReturns extends StatelessWidget {
  const EmptyReturns({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No returns yet',
      icon: Icons.assignment_return,
    );
  }
}

class EmptyUsers extends StatelessWidget {
  const EmptyUsers({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No users yet',
      icon: Icons.people_outline,
    );
  }
}

class EmptyWarehouses extends StatelessWidget {
  const EmptyWarehouses({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No warehouses yet',
      icon: Icons.warehouse_outlined,
    );
  }
}

class EmptyRecordings extends StatelessWidget {
  const EmptyRecordings({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No recordings yet',
      icon: Icons.videocam_off_outlined,
    );
  }
}

class EmptyAlerts extends StatelessWidget {
  const EmptyAlerts({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No alerts',
      icon: Icons.notifications_off_outlined,
    );
  }
}

class EmptyConnections extends StatelessWidget {
  const EmptyConnections({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      message: 'No connections yet',
      icon: Icons.link_off,
    );
  }
}

class EmptyData extends StatelessWidget {
  final String message;
  final IconData? icon;
  const EmptyData({super.key, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      message: message,
      icon: icon ?? Icons.inbox_outlined,
    );
  }
}