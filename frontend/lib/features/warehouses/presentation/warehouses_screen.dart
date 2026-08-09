import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<dynamic> _all = [];
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/warehouses');
      final list = _asList(res.data);
      setState(() {
        _all = list;
        _loading = false;
        if (_selected == null && list.isNotEmpty && list.first is Map) {
          _selected = Map<String, dynamic>.from(list.first as Map);
        }
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    if (_q.isEmpty) return _all;
    final q = _q.toLowerCase();
    return _all.where((w) {
      if (w is! Map) return false;
      return '${w['name']} ${w['code']} ${w['city']} ${w['address']}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  int get _active =>
      _all.where((w) => w is Map && (w['status']?.toString() == 'active')).length;
  int get _inactive => _all.length - _active;

  int _stationCount(Map w) {
    final s = w['stations'];
    if (s is List) return s.length;
    if (w['stationCount'] is num) return (w['stationCount'] as num).toInt();
    return 0;
  }

  Future<void> _addWarehouse() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Warehouse'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Code (e.g. WH-NE-001)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(
                      labelText: 'City', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Address', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name required')));
      return;
    }
    try {
      await ApiClient.instance.dio.post('/warehouses', data: {
        'name': nameCtrl.text.trim(),
        if (codeCtrl.text.trim().isNotEmpty) 'code': codeCtrl.text.trim(),
        if (cityCtrl.text.trim().isNotEmpty) 'city': cityCtrl.text.trim(),
        if (addressCtrl.text.trim().isNotEmpty)
          'address': addressCtrl.text.trim(),
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warehouse created')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                e.response?.data?.toString() ?? e.message ?? 'Create failed')));
      }
    }
  }

  Future<void> _toggleStatus(Map w) async {
    final id = w['id']?.toString();
    if (id == null) return;
    final cur = w['status']?.toString() ?? 'active';
    final next = cur == 'active' ? 'inactive' : 'active';
    final confirm = await AppDialogs.confirm(
      context,
      title: next == 'inactive' ? 'Deactivate warehouse?' : 'Activate?',
      message: '${w['name']} → $next',
    );
    if (confirm != true) return;
    try {
      await ApiClient.instance.dio
          .patch('/warehouses/$id', data: {'status': next});
      _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Update failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final filtered = _filtered;
    var stationsTotal = 0;
    for (final w in _all) {
      if (w is Map) stationsTotal += _stationCount(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Warehouses',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Manage and monitor all your warehouses from a single place.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addWarehouse,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Warehouse'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: LayoutBuilder(builder: (context, c) {
            final cross = c.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                _Kpi('Total Warehouses', '${_all.length}', Icons.warehouse,
                    const Color(0xFF3B82F6)),
                _Kpi('Active', '$_active', Icons.check_circle,
                    const Color(0xFF22C55E)),
                _Kpi('Inactive', '$_inactive', Icons.pause_circle,
                    const Color(0xFFF59E0B)),
                _Kpi('Packing Stations', '$stationsTotal', Icons.grid_view,
                    const Color(0xFF8B5CF6)),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search warehouses…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.danger)))
                  : isWide
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: _list(filtered)),
                            SizedBox(width: 300, child: _detail()),
                          ],
                        )
                      : _list(filtered),
        ),
      ],
    );
  }

  Widget _list(List<dynamic> filtered) {
    if (filtered.isEmpty) {
      return const Center(
          child: Text('No warehouses — add your first warehouse'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final w = filtered[i] as Map<String, dynamic>;
        final name = w['name']?.toString() ?? '—';
        final code = w['code']?.toString() ?? '';
        final status = w['status']?.toString() ?? 'active';
        final city = w['city']?.toString() ?? w['address']?.toString() ?? '';
        final stations = _stationCount(w);
        final active = status == 'active';
        final sel = _selected?['id'] == w['id'];
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';

        return InkWell(
          onTap: () => setState(() => _selected = w),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? const Color(0xFF2563EB) : AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(initial,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      if (code.isNotEmpty)
                        Text(code,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(city.isEmpty ? '—' : city,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 70,
                  child: Text('$stations stn',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detail() {
    final w = _selected;
    if (w == null) {
      return Container(
        margin: const EdgeInsets.only(right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
            child: Text('Select a warehouse',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    final status = w['status']?.toString() ?? 'active';
    final stations = w['stations'];
    final stationList = stations is List ? stations : <dynamic>[];

    return Container(
      margin: const EdgeInsets.only(right: 24, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(
        children: [
          const Text('Warehouse Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          _row('Name', w['name']?.toString() ?? '—'),
          _row('Code', w['code']?.toString() ?? '—'),
          _row('Status', status),
          _row('City', w['city']?.toString() ?? '—'),
          _row('Address', w['address']?.toString() ?? '—'),
          _row('Stations', '${stationList.length}'),
          if (stationList.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Stations',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            for (final s in stationList)
              if (s is Map)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${s['name'] ?? s['code'] ?? s['id']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _toggleStatus(w),
            icon: Icon(
              status == 'active' ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: status == 'active' ? Colors.red : const Color(0xFF16A34A),
            ),
            label: Text(
              status == 'active' ? 'Deactivate' : 'Activate',
              style: TextStyle(
                  color: status == 'active'
                      ? Colors.red
                      : const Color(0xFF16A34A)),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Kpi extends StatelessWidget {
  final String t, v;
  final IconData i;
  final Color c;
  const _Kpi(this.t, this.v, this.i, this.c);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(v,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(t,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}