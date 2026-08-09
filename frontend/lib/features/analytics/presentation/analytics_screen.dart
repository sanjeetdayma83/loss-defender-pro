import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  String? _error;

  int _orders = 0;
  int _verified = 0;
  int _recordings = 0;
  int _claims = 0;
  int _exceptions = 0;
  int _warehouses = 0;
  int _users = 0;
  int _evidence = 0;
  int _storageUsed = 0;
  int _storageQuota = 10737418240;

  final Map<String, int> _statusCounts = {};
  List<dynamic> _topWarehouses = [];
  List<dynamic> _recentOrders = [];

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

  Map<String, dynamic>? _asMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.dio.get('/orders').catchError((_) => null),
        ApiClient.instance.dio.get('/warehouses').catchError((_) => null),
        ApiClient.instance.dio.get('/users').catchError((_) => null),
        ApiClient.instance.dio.get('/recordings').catchError((_) => null),
        ApiClient.instance.dio.get('/evidence').catchError((_) => null),
        ApiClient.instance.dio.get('/claims').catchError((_) => null),
        ApiClient.instance.dio.get('/companies/me').catchError((_) => null),
        ApiClient.instance.dio.get('/analytics/kpis').catchError((_) => null),
      ]);

      final orders = results[0] != null ? _asList(results[0].data) : <dynamic>[];
      final warehouses =
          results[1] != null ? _asList(results[1].data) : <dynamic>[];
      final users = results[2] != null ? _asList(results[2].data) : <dynamic>[];
      final recordings =
          results[3] != null ? _asList(results[3].data) : <dynamic>[];
      final evidence =
          results[4] != null ? _asList(results[4].data) : <dynamic>[];
      final claims =
          results[5] != null ? _asList(results[5].data) : <dynamic>[];
      final company =
          results[6] != null ? _asMap(results[6].data) : null;
      final kpis =
          results[7] != null ? _asMap(results[7].data) : null;

      final statusMap = <String, int>{};
      var verified = 0;
      var exceptions = 0;
      for (final o in orders) {
        if (o is! Map) continue;
        final s = (o['status']?.toString() ?? 'unknown').toLowerCase();
        statusMap[s] = (statusMap[s] ?? 0) + 1;
        if (['dispatched', 'shipped', 'closed', 'verified', 'scanned']
            .contains(s)) {
          verified++;
        }
        if (['claimed', 'returned', 'failed', 'exception'].contains(s)) {
          exceptions++;
        }
      }

      if (!mounted) return;
      setState(() {
        _orders = kpis?['ordersTotal'] is num
            ? (kpis!['ordersTotal'] as num).toInt()
            : orders.length;
        _verified = kpis?['ordersVerified'] is num
            ? (kpis!['ordersVerified'] as num).toInt()
            : verified;
        _recordings = recordings.length;
        _claims = claims.length;
        _exceptions = exceptions;
        _warehouses = warehouses.length;
        _users = users.length;
        _evidence = evidence.length;
        _storageUsed =
            int.tryParse('${company?['storageUsed'] ?? 0}') ?? 0;
        _storageQuota =
            int.tryParse('${company?['storageQuota'] ?? 10737418240}') ??
                10737418240;
        _statusCounts
          ..clear()
          ..addAll(statusMap);
        _topWarehouses = warehouses.take(5).toList();
        _recentOrders = orders.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtBytes(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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

    final storagePct = _storageQuota > 0
        ? (_storageUsed / _storageQuota).clamp(0.0, 1.0)
        : 0.0;
    final verifyRate =
        _orders > 0 ? (_verified / _orders * 100) : 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics Dashboard',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                        'Real-time insights and performance overview of your warehouse operations.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 20),

          // KPI grid
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
              childAspectRatio: c.maxWidth > 1000 ? 1.4 : 1.7,
              children: [
                _Kpi('Total Orders', '$_orders', Icons.receipt_long,
                    const Color(0xFF3B82F6)),
                _Kpi('Verified', '$_verified', Icons.verified,
                    const Color(0xFF22C55E)),
                _Kpi('Recordings', '$_recordings', Icons.videocam,
                    const Color(0xFF8B5CF6)),
                _Kpi('Claims', '$_claims', Icons.gavel,
                    const Color(0xFFF59E0B)),
                _Kpi('Exceptions', '$_exceptions', Icons.warning_amber,
                    const Color(0xFFEF4444)),
                _Kpi('Evidence', '$_evidence', Icons.photo_library,
                    const Color(0xFF06B6D4)),
              ],
            );
          }),
          const SizedBox(height: 20),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _statusCard()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _storageCard(storagePct, verifyRate)),
              ],
            )
          else ...[
            _statusCard(),
            const SizedBox(height: 16),
            _storageCard(storagePct, verifyRate),
          ],
          const SizedBox(height: 16),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _warehouseCard()),
                const SizedBox(width: 16),
                Expanded(child: _recentCard()),
              ],
            )
          else ...[
            _warehouseCard(),
            const SizedBox(height: 16),
            _recentCard(),
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    final entries = _statusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = _statusCounts.values.fold<int>(0, (a, b) => a + b);

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
          const Text('Orders by Status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text('No order data yet',
                style: TextStyle(color: AppColors.textSecondary))
          else
            for (final e in entries.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(e.key,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? e.value / total : 0,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text('${e.value}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _storageCard(double storagePct, double verifyRate) {
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
          const Text('Key Metrics',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          _metricRow('Verification rate',
              '${verifyRate.toStringAsFixed(1)}%'),
          _metricRow('Warehouses', '$_warehouses'),
          _metricRow('Team members', '$_users'),
          _metricRow('Storage used',
              '${_fmtBytes(_storageUsed)} / ${_fmtBytes(_storageQuota)}'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: storagePct,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: storagePct > 0.9
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(storagePct * 100).toStringAsFixed(0)}% used',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _metricRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(v,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _warehouseCard() {
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
          const Text('Warehouses',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          if (_topWarehouses.isEmpty)
            const Text('No warehouses',
                style: TextStyle(color: AppColors.textSecondary))
          else
            for (var i = 0; i < _topWarehouses.length; i++)
              if (_topWarehouses[i] is Map)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            const Color(0xFF2563EB).withOpacity(0.1),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (_topWarehouses[i] as Map)['name']?.toString() ??
                              '—',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        (_topWarehouses[i] as Map)['status']?.toString() ??
                            '',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _recentCard() {
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
            const Text('No orders yet',
                style: TextStyle(color: AppColors.textSecondary))
          else
            for (final o in _recentOrders)
              if (o is Map)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o['marketplaceOrderId']?.toString() ??
                              o['id']?.toString() ??
                              '—',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(o['status']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, color: c, size: 18),
          ),
          const Spacer(),
          Text(v,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          Text(t,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}