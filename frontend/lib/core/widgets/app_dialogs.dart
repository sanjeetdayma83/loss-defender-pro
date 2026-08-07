import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared dialogs matching Loss Defender Pro modal design system.
class AppDialogs {
  AppDialogs._();

  // ─── Core builder ───────────────────────────────────────────
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: child,
        ),
      ),
    );
  }

  // ─── 1. Confirm Action ──────────────────────────────────────
  static Future<bool> confirmAction(
    BuildContext context, {
    String title = 'Confirm Action',
    String message = 'Are you sure you want to proceed?',
    String confirmLabel = 'Confirm',
    Color confirmColor = const Color(0xFF2563EB),
  }) async {
    final r = await show<bool>(
      context: context,
      child: _ModalShell(
        icon: Icons.priority_high_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        title: title,
        message: message,
        actions: [
          _btn(context, 'Cancel', false),
          _btn(context, confirmLabel, true, filled: true, color: confirmColor),
        ],
      ),
    );
    return r == true;
  }

  // ─── 2. Delete Confirmation ─────────────────────────────────
  static Future<bool> confirmDelete(
    BuildContext context, {
    String title = 'Delete',
    String message = 'This action cannot be undone.',
  }) async {
    final r = await show<bool>(
      context: context,
      child: _ModalShell(
        icon: Icons.delete_outline_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        title: title,
        message: message,
        actions: [
          _btn(context, 'Cancel', false),
          _btn(context, 'Delete', true, filled: true, color: const Color(0xFFDC2626)),
        ],
      ),
    );
    return r == true;
  }

  // ─── 3. Success ─────────────────────────────────────────────
  static Future<void> success(
    BuildContext context, {
    String title = 'Success!',
    String message = 'Operation completed successfully.',
  }) {
    return show(
      context: context,
      child: _ModalShell(
        icon: Icons.check_circle_outline_rounded,
        iconBg: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        title: title,
        message: message,
        actions: [
          _btn(context, 'Okay', true, filled: true),
        ],
      ),
    );
  }

  // ─── 4. Error / Failure ─────────────────────────────────────
  static Future<void> error(
    BuildContext context, {
    String title = 'Something went wrong!',
    String message = 'Unable to save the changes. Please try again later.',
  }) {
    return show(
      context: context,
      child: _ModalShell(
        icon: Icons.cancel_outlined,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        title: title,
        message: message,
        actions: [
          _btn(context, 'Try Again', true, filled: true),
        ],
      ),
    );
  }

  // ─── 5. Information ─────────────────────────────────────────
  static Future<void> info(
    BuildContext context, {
    String title = 'Information',
    String message = '',
  }) {
    return show(
      context: context,
      child: _ModalShell(
        icon: Icons.info_outline_rounded,
        iconBg: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
        title: title,
        message: message,
        actions: [
          _btn(context, 'Got It', true, filled: true),
        ],
      ),
    );
  }

  // ─── 6. Warning ─────────────────────────────────────────────
  static Future<bool?> warning(
    BuildContext context, {
    String title = 'Warning',
    String message = '',
    String primaryLabel = 'Continue',
    String secondaryLabel = 'Later',
  }) {
    return show<bool>(
      context: context,
      child: _ModalShell(
        icon: Icons.warning_amber_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        title: title,
        message: message,
        actions: [
          _btn(context, primaryLabel, true, filled: true),
          _btn(context, secondaryLabel, false),
        ],
      ),
    );
  }

  // ─── 7. Logout Confirmation ─────────────────────────────────
  static Future<bool> confirmLogout(BuildContext context) async {
    final r = await show<bool>(
      context: context,
      child: _ModalShell(
        icon: Icons.logout_rounded,
        iconBg: const Color(0xFFEDE9FE),
        iconColor: const Color(0xFF7C3AED),
        title: 'Logout',
        message: 'Are you sure you want to logout from your account?',
        actions: [
          _btn(context, 'Cancel', false),
          _btn(context, 'Logout', true, filled: true, color: const Color(0xFFDC2626)),
        ],
      ),
    );
    return r == true;
  }

  // ─── 8. Session Expired ─────────────────────────────────────
  static Future<void> sessionExpired(BuildContext context) {
    return show(
      context: context,
      barrierDismissible: false,
      child: _ModalShell(
        icon: Icons.timer_outlined,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        title: 'Session Expired',
        message:
            'Your session has expired due to inactivity. Please login again.',
        actions: [
          _btn(context, 'Go to Login', true, filled: true),
        ],
      ),
    );
  }

  // ─── 9. Unsaved Changes ─────────────────────────────────────
  static Future<String?> unsavedChanges(BuildContext context) {
    return show<String>(
      context: context,
      child: _ModalShell(
        icon: Icons.description_outlined,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        title: 'Unsaved Changes',
        message: 'You have unsaved changes. Do you want to save before leaving?',
        actions: [
          _btn(context, 'Discard', 'discard'),
          _btn(context, 'Cancel', null),
          _btn(context, 'Save Changes', 'save', filled: true),
        ],
      ),
    );
  }

  // ─── 10. Remove Item ────────────────────────────────────────
  static Future<bool> confirmRemove(
    BuildContext context, {
    String message = 'Are you sure you want to remove this item from the list?',
  }) async {
    final r = await show<bool>(
      context: context,
      child: _ModalShell(
        icon: Icons.delete_outline_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        title: 'Remove Item',
        message: message,
        actions: [
          _btn(context, 'Cancel', false),
          _btn(context, 'Remove', true, filled: true, color: const Color(0xFFDC2626)),
        ],
      ),
    );
    return r == true;
  }

  // ─── 11. Duplicate Scan Alert ───────────────────────────────
  static Future<void> duplicateScan(
    BuildContext context, {
    String message = 'This barcode has already been scanned.',
  }) {
    return show(
      context: context,
      child: _ModalShell(
        icon: Icons.qr_code_scanner_rounded,
        iconBg: const Color(0xFFE0E7FF),
        iconColor: const Color(0xFF4F46E5),
        title: 'Duplicate Scan Detected',
        message: message,
        actions: [
          _btn(context, 'View Details', true, filled: true),
        ],
      ),
    );
  }

  // ─── 12. Network Error ──────────────────────────────────────
  static Future<bool> networkError(BuildContext context) async {
    final r = await show<bool>(
      context: context,
      child: _ModalShell(
        icon: Icons.wifi_off_rounded,
        iconBg: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF64748B),
        title: 'No Internet Connection',
        message: 'Please check your internet connection and try again.',
        actions: [
          _btn(context, 'Cancel', false),
          _btn(context, 'Retry', true, filled: true),
        ],
      ),
    );
    return r == true;
  }

  // ─── 18. Invite User (form) ─────────────────────────────────
  static Future<Map<String, String>?> inviteUser(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'packing_operator';

    return show<Map<String, String>>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Invite User',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (ctx, setLocal) => DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'packing_operator',
                      child: Text('Packing Operator')),
                  DropdownMenuItem(
                      value: 'qc_operator', child: Text('QC Operator')),
                  DropdownMenuItem(
                      value: 'supervisor', child: Text('Supervisor')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(
                      value: 'claims_executive',
                      child: Text('Claims Executive')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                ],
                onChanged: (v) => setLocal(() => role = v ?? role),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context, {
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': role,
                    });
                  },
                  child: const Text('Send Invite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── helpers ────────────────────────────────────────────────
  static Widget _btn(
    BuildContext context,
    String label,
    dynamic value, {
    bool filled = false,
    Color color = const Color(0xFF2563EB),
  }) {
    if (filled) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: () => Navigator.pop(context, value),
        child: Text(label),
      );
    }
    return TextButton(
      onPressed: () => Navigator.pop(context, value),
      child: Text(label),
    );
  }
}

class _ModalShell extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;

  const _ModalShell({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }
}