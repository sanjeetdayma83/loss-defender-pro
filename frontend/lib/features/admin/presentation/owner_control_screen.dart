import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/rbac/rbac_state.dart';

class OwnerControlScreen extends StatefulWidget {
  const OwnerControlScreen({super.key});
  @override
  State<OwnerControlScreen> createState() => _OwnerControlScreenState();
}

class _OwnerControlScreenState extends State<OwnerControlScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  RbacState _rbac = RbacState.empty();
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _company;
  Map<String, dynamic>? _catalog;
  bool _loading = true;
  String? _error;

  static const roles = [
    'owner',
    'admin',
    'warehouse_manager',
    'supervisor',
    'packing_operator',
    'viewer',
  ];

  static const roleHelp = {
    'owner': 'Full access: billing, users, warehouses, all ops',
    'admin': 'Almost full; manage ops & settings',
    'warehouse_manager': 'Warehouse ops, users invite, claims/returns',
    'supervisor': 'Floor: scan, record, dispatch, claims',
    'packing_operator': 'Scan + record + evidence only',
    'viewer': 'Read-only orders/evidence/analytics',
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _rbac = await RbacState.load();
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([
        dio.get('/users'),
        dio.get('/companies/me'),
        dio.get('/billing/plans'),
      ]);
      List listOf(dynamic res) {
        final b = res.data;
        final d = b is Map && b['data'] != null ? b['data'] : b;
        return d is List ? d : [];
      }
      Map<String, dynamic> mapOf(dynamic res) {
        final b = res.data;
        final d = b is Map && b['data'] != null ? b['data'] : b;
        return d is Map ? Map<String, dynamic>.from(Map<String, dynamic>.from(d as Map)) : <String, dynamic>{};
      }
      setState(() {
        _users = listOf(results[0]).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _company = Map<String, dynamic>.from(mapOf(results[1]));
        _catalog = Map<String, dynamic>.from(mapOf(results[2]));
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  Future<void> _setPlan(String planId) async {
    try {
      final co = await ApiClient.instance.dio.post('/billing/checkout/plan', data: {'planId': planId});
      final data = co.data is Map && co.data['data'] != null ? co.data['data'] : co.data;
      final order = data is Map ? data['order'] : null;
      final orderId = order is Map ? order['id']?.toString() : null;
      if (orderId == null) return;
      await ApiClient.instance.dio.post('/billing/checkout/verify', data: {
        'planId': planId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': 'pay_admin_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_signature': 'mock',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan set to $planId')));
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Plan update failed')),
        );
      }
    }
  }

  Future<void> _invite() async {
    final email = TextEditingController();
    String role = 'packing_operator';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invite')),
        ],
      ),
    );
    if (ok != true || email.text.trim().isEmpty) return;
    try {
      final res = await ApiClient.instance.dio.post('/users/invite', data: {
        'email': email.text.trim(),
        'role': role,
      });
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      final temp = data is Map ? data['tempPassword'] : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(temp != null ? 'Invited. Temp: $temp' : 'Invite sent')),
        );
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Invite failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = (_catalog?['plans'] is List) ? _catalog!['plans'] as List : [];
    final limits = _rbac.limits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Owner Control Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Chip(label: Text('${_rbac.role} · ${_rbac.plan}')),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Roles & Access'),
            Tab(text: 'Plans'),
            Tab(text: 'Users'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // OVERVIEW
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(_company?['name']?.toString() ?? 'Company'),
                      subtitle: Text('Plan: ${_rbac.plan} · Storage ${_company?['storageUsed'] ?? 0}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Limits (from plan)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Users max: ${limits['userLimit'] ?? '—'}')),
                          Chip(label: Text('Warehouses max: ${limits['warehouseLimit'] ?? '—'}')),
                          Chip(label: Text('Scans pack: ${limits['scans'] ?? '—'}')),
                          Chip(label: Text('Validity days: ${limits['validityDays'] ?? '—'}')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Plan features', style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8,
                    children: _rbac.features.map((f) => Chip(avatar: const Icon(Icons.check, size: 16), label: Text(f))).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your permissions', style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _rbac.permissions.map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 11)))).toList(),
                  ),
                ],
              ),
              // ROLES MATRIX
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Role → what they can do', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...roles.map((r) => Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(r.substring(0, 1).toUpperCase())),
                          title: Text(r),
                          subtitle: Text(roleHelp[r] ?? ''),
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Text('Route access (from API)', style: TextStyle(fontWeight: FontWeight.w600)),
                  ..._rbac.navAllowed.map((p) => ListTile(dense: true, leading: const Icon(Icons.link, size: 18), title: Text(p))),
                ],
              ),
              // PLANS
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Change subscription plan', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Razorpay keys optional — mock verify works in dev', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...plans.map((raw) {
                    final p = raw is Map ? Map<String, dynamic>.from(raw as Map) : <String, dynamic>{};
                    final id = p['id']?.toString() ?? '';
                    final current = id == _rbac.plan;
                    return Card(
                      child: ListTile(
                        title: Text('${p['name']} — ₹${p['priceInr']} / ${p['intervalMonths']} mo'),
                        subtitle: Text('${p['scans']} scans · ${p['userLimit']} users · ${p['warehouseLimit']} WH'),
                        trailing: current
                            ? const Chip(label: Text('Current'))
                            : FilledButton(
                                onPressed: _rbac.can('billing.manage') ? () => _setPlan(id) : null,
                                child: const Text('Activate'),
                              ),
                      ),
                    );
                  }),
                ],
              ),
              // USERS
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Team', style: TextStyle(fontWeight: FontWeight.w600))),
                      FilledButton.icon(
                        onPressed: _rbac.can('user.invite') ? _invite : null,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                  Text('User limit: ${_users.length} / ${limits['userLimit'] ?? '—'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ..._users.map((u) => Card(
                        child: ListTile(
                          title: Text(u['email']?.toString() ?? u['name']?.toString() ?? '—'),
                          subtitle: Text('Role: ${u['role'] ?? '—'}'),
                          trailing: Text(u['status']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
