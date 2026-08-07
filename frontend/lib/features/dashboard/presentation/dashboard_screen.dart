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
  bool _loading = true;
  String? _error;

  int orders = 0, pending = 0, verified = 0, exceptions = 0;
  int recordings = 0, evidence = 0, users = 0, warehouses = 0;
  int readyDispatch = 0;
  List<dynamic> _recentOrders = [];
  List<dynamic> _stations = [];

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

  Future<List<dynamic>> _get(String path) async {
    try {
      final res = await ApiClient.instance.dio.get(path);
      return _asList(res.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orderList = await _get('/orders');
      final recList = await _get('/recordings');
      final evList = await _get('/evidence');
      final userList = await _get('/users');
      final whList = await _get('/warehouses');

      int p = 0, v = 0, e = 0, rd = 0;
      for (final o in orderList) {
        if (o is! Map) continue;
        final s = (o['status']?.toString() ?? '').toLowerCase();
        if (['queued', 'synced', 'pending', 'packing', 'scanned'].contains(s)) p++;
        if (['shipped', 'closed', 'dispatched', 'evidence_ready'].contains(s)) v++;
        if (['failed', 'exception', 'claimed', 'returned'].contains(s)) e++;
        if (['scanned', 'evidence_ready', 'packing', 'recording', 'queued'].contains(s)) rd++;
      }

      final stations = <dynamic>[];
      for (final w in whList) {
        if (w is Map && w['stations'] is List) {
          for (final s in w['stations'] as List) {
            stations.add({...Map<String, dynamic>.from(s as Map), 'warehouse': w['name']});
          }
        }
      }

      if (!mounted) return;
      setState(() {
        orders = orderList.length;
        pending = p;
        verified = v;
        exceptions = e;
        readyDispatch = rd;
        recordings = recList.length;
        evidence = evList.length;
        users = userList.length;
        warehouses = whList.length;
        _recentOrders = orderList.take(8).toList();
        _stations = stations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                          'Real-time overview of your warehouse operations and performance.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Today',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final cross = c.maxWidth > 1000
                  ? 6
                  : c.maxWidth > 700
                      ? 3
                      : 2;
              return GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _Kpi('Orders Today', '$orders', Icons.shopping_cart_outlined,
                      const Color(0xFF3B82F6)),
                  _Kpi('Orders Pending', '$pending', Icons.hourglass_empty,
                      const Color(0xFFF59E0B)),
                  _Kpi('Orders Verified', '$verified', Icons.verified_outlined,
                      const Color(0xFF22C55E)),
                  _Kpi('Exceptions', '$exceptions', Icons.warning_amber,
                      const Color(0xFFEF4444)),
                  _Kpi('Recordings', '$recordings', Icons.videocam_outlined,
                      const Color(0xFF8B5CF6)),
                  _Kpi('Active Operators', '$users', Icons.people_outline,
                      const Color(0xFF06B6D4)),
                ],
              );
            }),
            const SizedBox(height: 20),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _pipeline()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _stationsCard()),
                ],
              )
            else ...[
              _pipeline(),
              const SizedBox(height: 16),
              _stationsCard(),
            ],
            const SizedBox(height: 16),
            _recentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _pipeline() {
    final steps = [
      ('Synced', orders, const Color(0xFF3B82F6)),
      ('Pending', pending, const Color(0xFFF59E0B)),
      ('Ready', readyDispatch, const Color(0xFF8B5CF6)),
      ('Recording', recordings, const Color(0xFF06B6D4)),
      ('Evidence', evidence, const Color(0xFF22C55E)),
      ('Verified', verified, const Color(0xFF10B981)),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders Pipeline',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps.map((s) {
              return Container(
                width: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s.$3.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: s.$3.withOpacity(0.2),
                      child: Text('${s.$2}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: s.$3)),
                    ),
                    const SizedBox(height: 6),
                    Text(s.$1,
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: orders == 0 ? 0 : (verified / orders).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            orders == 0
                ? 'No orders yet'
                : '${((verified / orders) * 100).toStringAsFixed(1)}% completed',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _stationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Live Stations',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Text('${_stations.length} total',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_stations.isEmpty)
            const Text('No stations configured',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            ..._stations.take(6).map((s) {
              final m = s as Map;
              final online = (m['status']?.toString() ?? '') == 'online';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.desktop_windows_outlined,
                        size: 16,
                        color: online
                            ? const Color(0xFF22C55E)
                            : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m['stationName']?.toString() ??
                            m['stationId']?.toString() ??
                            '—',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(m['status']?.toString() ?? 'offline',
                        style: TextStyle(
                            fontSize: 11,
                            color: online
                                ? const Color(0xFF22C55E)
                                : AppColors.textSecondary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _recentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Orders',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          if (_recentOrders.isEmpty)
            const Text('No recent activity',
                style: TextStyle(color: AppColors.textSecondary))
          else
            ..._recentOrders.map((o) {
              final m = o as Map;
              final id = m['marketplaceOrderId']?.toString() ??
                  m['id']?.toString() ??
                  '—';
              final status = m['status']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(id,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(status,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, color: c, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(t,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}