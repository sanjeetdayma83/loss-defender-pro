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

  int orders = 0;
  int recordings = 0;
  int evidence = 0;
  int claims = 0;
  int returnsCount = 0;
  int users = 0;
  int warehouses = 0;
  int readyDispatch = 0;

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

  Future<List<dynamic>> _safeGet(String path) async {
    try {
      final res = await ApiClient.instance.dio.get(path);
      return _asList(res.data);
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orderList = await _safeGet('/orders');
      final recList = await _safeGet('/recordings');
      final evList = await _safeGet('/evidence');
      final claimList = await _safeGet('/claims');
      final retList = await _safeGet('/returns');
      final userList = await _safeGet('/users');
      final whList = await _safeGet('/warehouses');

      if (!mounted) return;
      setState(() {
        orders = orderList.length;
        recordings = recList.length;
        evidence = evList.length;
        claims = claimList.length;
        returnsCount = retList.length;
        users = userList.length;
        warehouses = whList.length;
        readyDispatch = orderList.where((o) {
          if (o is! Map) return false;
          final s = (o['status']?.toString() ?? '').toLowerCase();
          return ['scanned', 'evidence_ready', 'packing', 'recording', 'queued']
              .contains(s);
        }).length;
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
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                        'Live operational KPIs across orders, evidence and team',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              style: const TextStyle(color: AppColors.danger)),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isWide ? 24 : 16),
                      child: LayoutBuilder(builder: (context, c) {
                        final cross = c.maxWidth > 1000
                            ? 4
                            : c.maxWidth > 600
                                ? 2
                                : 1;
                        return GridView.count(
                          crossAxisCount: cross,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.6,
                          children: [
                            _Card('Orders', '$orders', Icons.list_alt,
                                const Color(0xFF2563EB)),
                            _Card('Ready to Dispatch', '$readyDispatch',
                                Icons.local_shipping, const Color(0xFF0891B2)),
                            _Card('Recordings', '$recordings',
                                Icons.videocam_outlined,
                                const Color(0xFF7C3AED)),
                            _Card('Evidence Packs', '$evidence',
                                Icons.photo_library_outlined,
                                const Color(0xFF16A34A)),
                            _Card('Open Claims', '$claims', Icons.gavel_outlined,
                                const Color(0xFFEF4444)),
                            _Card('Returns', '$returnsCount',
                                Icons.assignment_return_outlined,
                                const Color(0xFFF59E0B)),
                            _Card('Team Members', '$users', Icons.people_outline,
                                const Color(0xFF6366F1)),
                            _Card('Warehouses', '$warehouses',
                                Icons.warehouse_outlined,
                                const Color(0xFF0EA5E9)),
                          ],
                        );
                      }),
                    ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String t, v;
  final IconData i;
  final Color c;
  const _Card(this.t, this.v, this.i, this.c);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(i, color: c, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(t,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}