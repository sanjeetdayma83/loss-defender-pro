import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _kpis;
  List<dynamic> _orders = [];
  List<dynamic> _alerts = [];
  Map<String, dynamic>? _live;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([
        dio.get('/analytics/kpis').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: {'data': {}})),
        dio.get('/orders'),
        dio.get('/alerts').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: {'data': []})),
        dio.get('/supervisor/live').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: {'data': {}})),
      ]);
      Map<String, dynamic> unwrap(dynamic res) {
        final b = res.data;
        if (b is Map && b['data'] != null) {
          if (b['data'] is Map) return Map<String, dynamic>.from(b['data'] as Map);
        }
        return b is Map ? Map<String, dynamic>.from(b) : {};
      }
      List listUnwrap(dynamic res) {
        final b = res.data;
        final d = b is Map && b['data'] != null ? b['data'] : b;
        return d is List ? d : [];
      }
      setState(() {
        _kpis = unwrap(results[0]);
        _orders = listUnwrap(results[1]);
        _alerts = listUnwrap(results[2]);
        _live = unwrap(results[3]);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  int _countStatus(String s) =>
      _orders.where((o) => (o is Map ? o['status'] : '') == s).length;

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _kpis?['ordersTotal'] ?? _orders.length;
    final evidence = _kpis?['evidence'] ?? 0;
    final dispatched = _kpis?['ordersDispatched'] ?? _countStatus('dispatched');
    final packing = (_live?['packingOrders'] ?? _countStatus('packing')).toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 700;
            final row1 = Row(children: [
              _kpi('Orders', '$total', Icons.shopping_bag_outlined, AppColors.accent),
              const SizedBox(width: 8),
              _kpi('Evidence', '$evidence', Icons.photo_library_outlined, Colors.teal),
              const SizedBox(width: 8),
              _kpi('Dispatched', '$dispatched', Icons.local_shipping_outlined, Colors.indigo),
              if (wide) ...[
                const SizedBox(width: 8),
                _kpi('Packing live', packing, Icons.inventory_2_outlined, Colors.orange),
              ],
            ]);
            return row1;
          }),
          const SizedBox(height: 16),
          const Text('Orders pipeline', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final e in [
                    ['packing', _countStatus('packing')],
                    ['recording', _countStatus('recording')],
                    ['scanned', _countStatus('scanned')],
                    ['evidence_ready', _countStatus('evidence_ready')],
                    ['dispatched', _countStatus('dispatched')],
                  ])
                    Chip(label: Text('${e[0]}: ${e[1]}')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Live floor', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text('Active recordings: ${_live?['activeRecordings'] ?? 0}'),
              subtitle: Text('Packing orders: ${_live?['packingOrders'] ?? 0}'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_alerts.isEmpty)
            const Card(child: ListTile(title: Text('No alerts')))
          else
            ..._alerts.take(5).map((a) {
              final m = a is Map ? Map<String, dynamic>.from(a as Map) : <String, dynamic>{};
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.notification_important_outlined, color: Colors.orange),
                  title: Text(m['title']?.toString() ?? m['type']?.toString() ?? 'Alert'),
                  subtitle: Text(m['message']?.toString() ?? m['body']?.toString() ?? ''),
                ),
              );
            }),
          const SizedBox(height: 16),
          const Text('Recent orders', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._orders.take(8).map((o) {
            final m = o is Map ? Map<String, dynamic>.from(o as Map) : <String, dynamic>{};
            return Card(
              child: ListTile(
                title: Text(m['marketplaceOrderId']?.toString() ?? m['id']?.toString() ?? '—'),
                subtitle: Text('${m['customerName'] ?? ''} · ${m['status'] ?? ''}'),
                dense: true,
              ),
            );
          }),
        ],
      ),
    );
  }
}
