import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<dynamic> _list = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
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
      Map<String, dynamic>? found;
      if (_selected != null) {
        final id = _selected!['id'];
        for (final item in list) {
          if (item is Map && item['id'] == id) {
            found = Map<String, dynamic>.from(item);
            break;
          }
        }
      }
      setState(() {
        _list = list;
        _selected = found;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Warehouse'),
        content: SizedBox(
          width: 360,
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
                    labelText: 'Code * (e.g. WH-MUM-01)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(
                    labelText: 'City *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stateCtrl,
                decoration: const InputDecoration(
                    labelText: 'State *', border: OutlineInputBorder()),
              ),
            ],
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

    if (ok != true ||
        nameCtrl.text.trim().isEmpty ||
        codeCtrl.text.trim().isEmpty ||
        cityCtrl.text.trim().isEmpty) return;

    try {
      await ApiClient.instance.dio.post('/warehouses', data: {
        'name': nameCtrl.text.trim(),
        'code': codeCtrl.text.trim().toUpperCase(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'address': {
          'line1': cityCtrl.text.trim(),
          'city': cityCtrl.text.trim(),
          'state': stateCtrl.text.trim(),
          'country': 'India',
        },
        'country': 'India',
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warehouse created')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.response?.data?['message'] ?? e.message ?? 'Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final totalStations = _list.fold<int>(0, (s, w) {
      if (w is! Map) return s;
      final stations = w['stations'];
      if (stations is List) return s + stations.length;
      final count = w['_count'];
      if (count is Map && count['stations'] is int) {
        return s + (count['stations'] as int);
      }
      return s;
    });

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
                    Text('Locations, packing stations and device health',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Warehouse'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: LayoutBuilder(builder: (context, c) {
            final cross = c.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _Kpi('Warehouses', '${_list.length}', Icons.warehouse_outlined,
                    const Color(0xFF2563EB)),
                _Kpi('Stations', '$totalStations',
                    Icons.desktop_windows_outlined, const Color(0xFF7C3AED)),
                _Kpi(
                    'Active',
                    '${_list.where((w) => w is Map && (w['status'] ?? 'active') == 'active').length}',
                    Icons.check_circle_outline,
                    const Color(0xFF16A34A)),
              ],
            );
          }),
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
                            Expanded(flex: 3, child: _listView()),
                            SizedBox(width: 320, child: _detail()),
                          ],
                        )
                      : _listView(),
        ),
      ],
    );
  }

  Widget _listView() {
    if (_list.isEmpty) {
      return const Center(child: Text('No warehouses yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
      itemCount: _list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final w = Map<String, dynamic>.from(_list[i] as Map);
        final stations = w['stations'];
        final stationCount = stations is List
            ? stations.length
            : (w['_count'] is Map ? (w['_count']['stations'] ?? 0) : 0);
        final sel = _selected?['id'] == w['id'];

        return InkWell(
          onTap: () => setState(() => _selected = w),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warehouse_outlined,
                      color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w['name']?.toString() ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        '${w['code'] ?? ''} · ${w['city'] ?? ''} · $stationCount stations',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (w['status'] ?? 'active').toString(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A)),
                  ),
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
    final stations = w['stations'] is List ? w['stations'] as List : [];

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
          Text(w['name']?.toString() ?? '—',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${w['code'] ?? ''} · ${w['city'] ?? ''}, ${w['state'] ?? ''}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          const Text('Stations',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          if (stations.isEmpty)
            const Text('No stations yet',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            ...stations.map((s) {
              final m = Map<String, dynamic>.from(s as Map);
              final online = (m['status']?.toString() ?? '') == 'online';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.desktop_windows_outlined,
                        size: 16,
                        color: online
                            ? const Color(0xFF16A34A)
                            : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m['stationName']?.toString() ??
                            m['stationId']?.toString() ??
                            '—',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(m['status']?.toString() ?? '—',
                        style: TextStyle(
                            fontSize: 11,
                            color: online
                                ? const Color(0xFF16A34A)
                                : AppColors.textSecondary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
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