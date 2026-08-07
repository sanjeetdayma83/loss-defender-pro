import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentPath;
  const AppShell({super.key, required this.child, required this.currentPath});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _usedLabel = '—';
  String _quotaLabel = '—';
  double _pct = 0;
  String _plan = '—';

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', '/dashboard'),
    _NavItem(Icons.list_alt_outlined, Icons.list_alt, 'Orders', '/orders'),
    _NavItem(Icons.qr_code_scanner, Icons.qr_code_scanner, 'Scanning', '/scanner'),
    _NavItem(Icons.videocam_outlined, Icons.videocam, 'Recordings', '/recording'),
    _NavItem(Icons.photo_library_outlined, Icons.photo_library, 'Evidence', '/evidence'),
    _NavItem(Icons.local_shipping_outlined, Icons.local_shipping, 'Dispatch', '/dispatch'),
    _NavItem(Icons.assignment_return_outlined, Icons.assignment_return, 'Returns', '/returns'),
    _NavItem(Icons.gavel_outlined, Icons.gavel, 'Claims', '/claims'),
    _NavItem(Icons.analytics_outlined, Icons.analytics, 'Analytics', '/analytics'),
    _NavItem(Icons.notifications_outlined, Icons.notifications, 'Alerts', '/alerts'),
    _NavItem(Icons.people_outline, Icons.people, 'Users & Roles', '/users'),
    _NavItem(Icons.warehouse_outlined, Icons.warehouse, 'Warehouses', '/warehouses'),
    _NavItem(Icons.storefront_outlined, Icons.storefront, 'Marketplace', '/marketplace'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings', '/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  String _fmtBytes(dynamic v) {
    if (v == null) return '0 B';
    final n = double.tryParse(v.toString()) ?? 0;
    if (n < 1024) return '${n.toStringAsFixed(0)} B';
    if (n < 1048576) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1073741824) return '${(n / 1048576).toStringAsFixed(1)} MB';
    return '${(n / 1073741824).toStringAsFixed(2)} GB';
  }

  Future<void> _loadStorage() async {
    try {
      final res = await ApiClient.instance.dio.get('/companies/me');
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      if (data is! Map) return;
      final used = double.tryParse('${data['storageUsed'] ?? 0}') ?? 0;
      final quota = double.tryParse('${data['storageQuota'] ?? 1}') ?? 1;
      if (!mounted) return;
      setState(() {
        _usedLabel = _fmtBytes(used);
        _quotaLabel = _fmtBytes(quota);
        _pct = quota > 0 ? (used / quota).clamp(0.0, 1.0) : 0;
        _plan = data['plan']?.toString() ?? 'free';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 960;

    if (!isWide) {
      return Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          height: 64,
          selectedIndex: _selectedIndex().clamp(0, 4),
          onDestinationSelected: (i) => context.go(_navItems[i].path),
          destinations: _navItems.take(5).map((e) {
            return NavigationDestination(
              icon: Icon(e.icon),
              selectedIcon: Icon(e.activeIcon),
              label: e.label,
            );
          }).toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248,
            color: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LOSS DEFENDER PRO',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.3)),
                            Text('Warehouse Intelligence',
                                style: TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: _navItems.map((item) {
                      final selected = widget.currentPath.startsWith(item.path);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: selected ? AppColors.primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => context.go(item.path),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(selected ? item.activeIcon : item.icon, size: 18,
                                      color: selected ? Colors.white : Colors.white60),
                                  const SizedBox(width: 12),
                                  Text(item.label,
                                      style: TextStyle(
                                        color: selected ? Colors.white : Colors.white70,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                        fontSize: 13,
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
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Storage Used', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('$_usedLabel / $_quotaLabel',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _pct,
                          minHeight: 5,
                          backgroundColor: Colors.white24,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_plan, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Text(_titleForPath(widget.currentPath),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const Spacer(),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by Order, Tracking No, SKU...',
                            hintStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentSoft,
                        child: Icon(Icons.person, size: 18, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _selectedIndex() {
    for (var i = 0; i < _navItems.length; i++) {
      if (widget.currentPath.startsWith(_navItems[i].path)) return i;
    }
    return 0;
  }

  String _titleForPath(String path) {
    for (final item in _navItems) {
      if (path.startsWith(item.path)) return item.label;
    }
    return 'Dashboard';
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label, path;
  const _NavItem(this.icon, this.activeIcon, this.label, this.path);
}