import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../../features/auth/data/auth_repository.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _company;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _nav = [
    _Nav('/dashboard', 'Dashboard', Icons.home_outlined, Icons.home),
    _Nav('/orders', 'Orders', Icons.list_alt_outlined, Icons.list_alt),
    _Nav('/scanner', 'Scanning', Icons.qr_code_scanner, Icons.qr_code_scanner),
    _Nav('/recording', 'Recordings', Icons.videocam_outlined, Icons.videocam),
    _Nav('/dispatch', 'Dispatch', Icons.local_shipping_outlined, Icons.local_shipping),
    _Nav('/returns', 'Returns', Icons.assignment_return_outlined, Icons.assignment_return),
    _Nav('/claims', 'Claims', Icons.gavel_outlined, Icons.gavel),
    _Nav('/evidence', 'Evidence', Icons.photo_library_outlined, Icons.photo_library),
    _Nav('/analytics', 'Analytics', Icons.bar_chart_outlined, Icons.bar_chart),
    _Nav('/users', 'Users & Roles', Icons.people_outline, Icons.people),
    _Nav('/warehouses', 'Warehouses', Icons.warehouse_outlined, Icons.warehouse),
    _Nav('/settings', 'Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      Map<String, dynamic>? user;
      try {
        final u = await ApiClient.instance.dio.get('/users/me');
        final body = u.data;
        final data = body is Map && body['data'] != null ? body['data'] : body;
        if (data is Map) user = Map<String, dynamic>.from(data);
      } catch (_) {}

      Map<String, dynamic>? company;
      try {
        final c = await ApiClient.instance.dio.get('/companies/me');
        final body = c.data;
        final data = body is Map && body['data'] != null ? body['data'] : body;
        if (data is Map) company = Map<String, dynamic>.from(data);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _user = user;
          _company = company;
        });
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final ok = await AppDialogs.confirmLogout(context);
    if (!ok) return;
    await AuthRepository().logout();
    if (mounted) context.go('/login');
  }

  void _openProfile() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final name = _user?['name']?.toString() ?? 'User';
        final email = _user?['email']?.toString() ?? '';
        final role = _user?['role']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text(email,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(role,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF2563EB))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // AppFormDialogs.changePassword(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                title: const Text('Logout',
                    style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () {
                  Navigator.pop(ctx);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _selected(String path) {
    if (path == '/dashboard') {
      return widget.location == '/dashboard' || widget.location == '/';
    }
    return widget.location.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1100;
    final companyName =
        _company?['companyName']?.toString() ?? 'Company';
    final userName = _user?['name']?.toString() ?? 'User';
    final userRole = _user?['role']?.toString() ?? '';

    final sidebar = _Sidebar(
      items: _nav,
      selected: _selected,
      onTap: (path) {
        if (!isWide) Navigator.pop(context);
        context.go(path);
      },
      companyName: companyName,
      storageUsed: _company?['storageUsed'],
      storageQuota: _company?['storageQuota'],
      plan: _company?['plan']?.toString(),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (isWide)
            SizedBox(width: 240, child: sidebar),
          Expanded(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!isWide)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                      // Company switcher
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business, size: 16,
                                color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                companyName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.expand_more, size: 18),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Notifications
                      IconButton(
                        icon: Badge(
                          isLabelVisible: true,
                          label: const Text('12',
                              style: TextStyle(fontSize: 10)),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 4),
                      // Profile
                      InkWell(
                        onTap: _openProfile,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    const Color(0xFF2563EB).withOpacity(0.15),
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB)),
                                ),
                              ),
                              if (width > 700) ...[
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(userName,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(userRole,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                                const Icon(Icons.expand_more, size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Page content ──────────────────────────────
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Nav {
  final String path, label;
  final IconData icon, iconSelected;
  const _Nav(this.path, this.label, this.icon, this.iconSelected);
}

class _Sidebar extends StatelessWidget {
  final List<_Nav> items;
  final bool Function(String) selected;
  final void Function(String) onTap;
  final String companyName;
  final dynamic storageUsed, storageQuota;
  final String? plan;

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onTap,
    required this.companyName,
    this.storageUsed,
    this.storageQuota,
    this.plan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LOSS DEFENDER',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.5)),
                      Text('PRO',
                          style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: items.map((n) {
                final sel = selected(n.path);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: sel
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onTap(n.path),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(sel ? n.iconSelected : n.icon,
                                size: 18,
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF94A3B8)),
                            const SizedBox(width: 10),
                            Text(n.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      sel ? FontWeight.w600 : FontWeight.w500,
                                  color: sel
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Storage footer
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_outlined,
                          size: 14, color: Color(0xFF94A3B8)),
                      SizedBox(width: 6),
                      Text('Storage Used',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.41,
                      backgroundColor: const Color(0xFF334155),
                      color: const Color(0xFF2563EB),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan != null ? 'Plan: $plan' : 'Professional',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}