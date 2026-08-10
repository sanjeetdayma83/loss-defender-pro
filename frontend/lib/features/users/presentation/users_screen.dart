import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _all = [];
  bool _loading = true;
  String? _error;
  String _tab = 'all';
  String _q = '';
  Map<String, dynamic>? _selected;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<dynamic> _asList(dynamic body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is List) return body;
    return [];
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/users');
      final list = _asList(res.data);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        if (_selected == null && list.isNotEmpty && list.first is Map) {
          _selected = Map<String, dynamic>.from(list.first as Map);
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Failed to load users';
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    var list = _all;
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) {
        if (u is! Map) return false;
        final s = '${u['name']} ${u['email']} ${u['role']} ${u['phone']}'.toLowerCase();
        return s.contains(q);
      }).toList();
    }
    switch (_tab) {
      case 'admins':
        return list.where((u) {
          final r = (u is Map ? u['role']?.toString() : '') ?? '';
          return r == 'owner' || r == 'super_admin' || r == 'manager';
        }).toList();
      case 'operators':
        return list.where((u) {
          final r = (u is Map ? u['role']?.toString() : '') ?? '';
          return r.contains('operator') || r == 'supervisor' || r == 'packing_operator' || r == 'scanner_operator';
        }).toList();
      case 'pending':
        return list.where((u) {
          final s = (u is Map ? u['status']?.toString() : '') ?? '';
          return s == 'invited' || s == 'pending';
        }).toList();
      case 'inactive':
        return list.where((u) {
          final s = (u is Map ? u['status']?.toString() : '') ?? '';
          return s == 'inactive' || s == 'disabled';
        }).toList();
      default:
        return list;
    }
  }

  int _countRole(bool Function(String role, String status) test) {
    return _all.where((u) {
      if (u is! Map) return false;
      return test(u['role']?.toString() ?? '', u['status']?.toString() ?? '');
    }).length;
  }

  String _roleLabel(String? r) {
    switch (r) {
      case 'owner':
      case 'super_admin': return 'Super Admin';
      case 'manager': return 'Manager';
      case 'supervisor': return 'Warehouse Lead';
      case 'packing_operator': return 'Packing Station';
      case 'scanner_operator': return 'Scanner Operator';
      case 'dispatcher': return 'Dispatcher';
      case 'viewer': return 'Viewer';
      default: return r ?? 'User';
    }
  }

  Color _roleColor(String? r) {
    switch (r) {
      case 'owner':
      case 'super_admin': return const Color(0xFF7C3AED);
      case 'manager':
      case 'supervisor': return const Color(0xFF2563EB);
      case 'packing_operator': return const Color(0xFF059669);
      case 'scanner_operator': return const Color(0xFFD97706);
      case 'dispatcher': return const Color(0xFF0891B2);
      default: return const Color(0xFF64748B);
    }
  }

  Future<void> _invite() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'packing_operator';
    const roles = ['manager', 'supervisor', 'packing_operator', 'scanner_operator', 'dispatcher', 'viewer'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add / Invite User'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: roles.map((e) => DropdownMenuItem(value: e, child: Text(_roleLabel(e)))).toList(),
                  onChanged: (v) => setLocal(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invite')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and email required')));
      return;
    }
    try {
      await ApiClient.instance.dio.post('/users/invite', data: {
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
        'role': role,
      });
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent')));
    } on DioException catch (e) {
      try {
        await ApiClient.instance.dio.post('/users', data: {
          'name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
          'role': role,
        });
        if (!mounted) return;
        await _load();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.data?.toString() ?? e.message ?? 'Invite failed')));
      }
    }
  }

  Future<void> _toggleStatus(Map u) async {
    final id = u['id']?.toString();
    if (id == null) return;
    final cur = u['status']?.toString() ?? 'active';
    final next = cur == 'active' ? 'inactive' : 'active';
    final confirm = await AppDialogs.confirm(context,
        title: next == 'inactive' ? 'Deactivate user?' : 'Activate user?',
        message: '${u['name'] ?? u['email']} → $next');
    if (confirm != true || !mounted) return;
    try {
      await ApiClient.instance.dio.patch('/users/$id', data: {'status': next});
      if (!mounted) return;
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Update failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final filtered = _filtered;
    final total = _all.length;
    final active = _countRole((_, s) => s == 'active');
    final pending = _countRole((_, s) => s == 'invited' || s == 'pending');
    final inactive = _countRole((_, s) => s == 'inactive' || s == 'disabled');
    final admins = _countRole((r, _) => r == 'owner' || r == 'super_admin' || r == 'manager');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 0),
          child: Row(
            children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Users & Roles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Manage team members, assign roles and control warehouse access.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ])),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: _invite, icon: const Icon(Icons.person_add_outlined, size: 18), label: const Text('Add User'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: LayoutBuilder(builder: (context, c) {
            final cross = c.maxWidth > 900 ? 5 : 2;
            return GridView.count(crossAxisCount: cross, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2, children: [
              _Kpi('Total Users', '$total', Icons.people, const Color(0xFF3B82F6)),
              _Kpi('Active', '$active', Icons.check_circle, const Color(0xFF22C55E)),
              _Kpi('Pending Invites', '$pending', Icons.mail_outline, const Color(0xFFF59E0B)),
              _Kpi('Inactive', '$inactive', Icons.person_off, const Color(0xFFEF4444)),
              _Kpi('Admins', '$admins', Icons.shield, const Color(0xFF8B5CF6)),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: TextField(controller: _searchCtrl, onChanged: (v) => setState(() => _q = v), decoration: InputDecoration(hintText: 'Search by name, email or role…', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)))),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _tabChip('All Users ($total)', 'all'),
            _tabChip('Admins ($admins)', 'admins'),
            _tabChip('Operators (${_countRole((r, _) => r.contains('operator') || r == 'supervisor')})', 'operators'),
            _tabChip('Pending ($pending)', 'pending'),
            _tabChip('Inactive ($inactive)', 'inactive'),
          ])),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                  : isWide
                      ? Row(children: [Expanded(flex: 3, child: _list(filtered)), SizedBox(width: 300, child: _detail())])
                      : _list(filtered),
        ),
      ],
    );
  }

  Widget _tabChip(String label, String key) {
    final sel = _tab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(onTap: () => setState(() => _tab = key), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sel ? const Color(0xFF2563EB) : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF2563EB) : AppColors.textSecondary)),
      )),
    );
  }

  Widget _list(List<dynamic> filtered) {
    if (filtered.isEmpty) return const Center(child: Text('No users'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = filtered[i] as Map<String, dynamic>;
        final name = u['name']?.toString() ?? '—';
        final email = u['email']?.toString() ?? '';
        final role = u['role']?.toString() ?? '';
        final status = u['status']?.toString() ?? 'active';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final rc = _roleColor(role);
        final sel = _selected?['id'] == u['id'];
        final active = status == 'active';
        return InkWell(onTap: () => setState(() => _selected = u), borderRadius: BorderRadius.circular(12), child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: sel ? const Color(0xFFEFF6FF) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? const Color(0xFF2563EB) : AppColors.border)),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: rc.withOpacity(0.15), child: Text(initial, style: TextStyle(fontWeight: FontWeight.w700, color: rc))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: rc.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(_roleLabel(role), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: rc))),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF16A34A) : AppColors.textSecondary))),
          ]),
        ));
      },
    );
  }

  Widget _detail() {
    final u = _selected;
    if (u == null) {
      return Container(margin: const EdgeInsets.only(right: 24, bottom: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: const Center(child: Text('Select a user', style: TextStyle(color: AppColors.textSecondary))));
    }
    final name = u['name']?.toString() ?? '—';
    final role = u['role']?.toString() ?? '';
    final status = u['status']?.toString() ?? 'active';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final rc = _roleColor(role);
    return Container(
      margin: const EdgeInsets.only(right: 24, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: ListView(children: [
        Row(children: [const Expanded(child: Text('User Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))), IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _selected = null))]),
        const SizedBox(height: 8),
        Center(child: CircleAvatar(radius: 36, backgroundColor: rc.withOpacity(0.15), child: Text(initial, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: rc)))),
        const SizedBox(height: 12),
        Center(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        const SizedBox(height: 4),
        Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: rc.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(_roleLabel(role), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rc)))),
        const SizedBox(height: 20),
        _row(Icons.mail_outline, 'Email', u['email']?.toString() ?? '—'),
        _row(Icons.phone_outlined, 'Phone', u['phone']?.toString() ?? '—'),
        _row(Icons.badge_outlined, 'Employee ID', u['employeeId']?.toString() ?? '—'),
        _row(Icons.circle, 'Status', status),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () => _toggleStatus(u), icon: Icon(status == 'active' ? Icons.person_off : Icons.person, size: 18, color: status == 'active' ? Colors.red : const Color(0xFF16A34A)), label: Text(status == 'active' ? 'Deactivate' : 'Activate', style: TextStyle(color: status == 'active' ? Colors.red : const Color(0xFF16A34A))), style: OutlinedButton.styleFrom(side: BorderSide(color: status == 'active' ? Colors.red : const Color(0xFF16A34A)), minimumSize: const Size.fromHeight(44))),
      ]),
    );
  }

  Widget _row(IconData i, String k, String v) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(i, size: 16, color: AppColors.textSecondary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]))]));
  }
}

class _Kpi extends StatelessWidget {
  final String t, v;
  final IconData i;
  final Color c;
  const _Kpi(this.t, this.v, this.i, this.c);
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(t, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
    ]));
  }
}
