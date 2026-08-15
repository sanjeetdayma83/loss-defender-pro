import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart'
    show AppColors, AppTheme;
import '../../../core/widgets/ui_kit.dart'
    show SectionCard, KpiStrip, KpiItem, EmptyHint, StatusPill, StatusBadge;

String _formatOrderId(Map<String, dynamic> order) {
  final marketplaceOrderId = order['marketplaceOrderId']?.toString();
  if (marketplaceOrderId != null && marketplaceOrderId.isNotEmpty) {
    return marketplaceOrderId;
  }
  final id = order['id']?.toString() ?? '';
  if (id.isEmpty) return '—';
  return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _kpis = {};
  List<dynamic> _orders = [];
  List<dynamic> _alerts = [];
  List<dynamic> _warehouses = [];
  Map<String, dynamic> _live = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic res) {
    final b = res is Response ? res.data : res;
    if (b is Map && b['data'] is Map) return Map<String, dynamic>.from(b['data'] as Map);
    if (b is Map) return Map<String, dynamic>.from(b);
    return {};
  }

  List<dynamic> _list(dynamic res) {
    final b = res is Response ? res.data : res;
    final d = b is Map && b['data'] != null ? b['data'] : b;
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'] as List;
    return [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.instance.dio;
      final empty = Response(requestOptions: RequestOptions(path: ''), data: {'data': {}});
      final emptyList = Response(requestOptions: RequestOptions(path: ''), data: {'data': []});
      final results = await Future.wait([
        dio.get('/analytics/kpis').catchError((_) => empty),
        dio.get('/orders').catchError((_) => emptyList),
        dio.get('/alerts').catchError((_) => emptyList),
        dio.get('/supervisor/live').catchError((_) => empty),
        dio.get('/warehouses').catchError((_) => emptyList),
      ]);
      setState(() {
        _kpis = _map(results[0]);
        _orders = _list(results[1]);
        _alerts = _list(results[2]);
        _live = _map(results[3]);
        _warehouses = _list(results[4]);
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
      _orders.where((o) => (o is Map ? '${o['status']}' : '') == s).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final ordersToday = '${_kpis['ordersToday'] ?? _kpis['orders_today'] ?? _orders.length}';
    final pipeline = '${_kpis['pipeline'] ?? _countStatus('packing') + _countStatus('recording')}';
    final stations = '${_live['stations'] ?? _warehouses.length}';
    final alertN = '${_alerts.length}';

    final pipelineSteps = [
      'queued',
      'packing',
      'recording',
      'evidence_ready',
      'dispatched',
      'shipped',
    ];

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
          const SizedBox(height: 12),
          KpiStrip(items: [
            KpiItem('Orders today', ordersToday, hint: 'live'),
            KpiItem('In pipeline', pipeline),
            KpiItem('Stations', stations, hint: 'active'),
            KpiItem('Alerts', alertN, hintColor: Colors.orange),
          ]),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Order pipeline',
            child: Row(
              children: pipelineSteps
                  .map(
                    (s) => Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.accent.withOpacity(0.12),
                            child: Text(
                              '${_countStatus(s)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.replaceAll('_', '\n'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SectionCard(
            title: '7-day trend',
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(7, (i) {
                        final t = _kpis['trend'];
                        double y = (i + 1).toDouble();
                        if (t is List && t.length > i) {
                          final v = t[i];
                          if (v is num) y = v.toDouble();
                          if (v is Map && v['count'] is num) y = (v['count'] as num).toDouble();
                        }
                        return FlSpot(i.toDouble(), y);
                      }),
                      isCurved: true,
                      barWidth: 3,
                      color: AppColors.accent,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppColors.accent.withOpacity(0.08)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SectionCard(
            title: 'Stations / warehouses',
            child: _warehouses.isEmpty
                ? const EmptyHint('No warehouses yet')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _warehouses.map((w) {
                      final m = w is Map ? w : <String, dynamic>{};
                      return Chip(
                        avatar: const Icon(Icons.warehouse_outlined, size: 16),
                        label: Text('${m['name'] ?? m['code'] ?? 'WH'} · ${m['status'] ?? 'active'}'),
                      );
                    }).toList(),
                  ),
          ),
          SectionCard(
            title: 'AI / rule alerts',
            child: _alerts.isEmpty
                ? const EmptyHint('No open alerts')
                : Column(
                    children: _alerts.take(6).map((a) {
                      final m = a is Map ? a : {'message': '$a'};
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber, color: Colors.orange),
                        title: Text('${m['message'] ?? m['type'] ?? m}'),
                        subtitle: Text('${m['severity'] ?? m['type'] ?? ''}'),
                      );
                    }).toList(),
                  ),
          ),
          SectionCard(
            title: 'Recent orders',
            child: _orders.isEmpty
                ? const EmptyHint('No orders')
                : Column(
                    children: _orders.take(8).map((o) {
                      final m = o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
                      final displayId = _formatOrderId(m);
                      final status = m['status']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(displayId.isNotEmpty ? displayId[0].toUpperCase() : '?'),
                        ),
                        title: Text(displayId),
                        trailing: StatusBadge(status: status, small: true),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
