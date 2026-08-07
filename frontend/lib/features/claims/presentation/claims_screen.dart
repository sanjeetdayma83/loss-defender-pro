import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});
  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  List<dynamic> _list = [];
  List<dynamic> _orders = [];
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
      final results = await Future.wait([
        ApiClient.instance.dio.get('/claims'),
        ApiClient.instance.dio.get('/orders'),
      ]);
      final cBody = results[0].data;
      final oBody = results[1].data;
      final cList = cBody is Map && cBody['data'] != null ? cBody['data'] : cBody;
      final oList = oBody is Map && oBody['data'] != null ? oBody['data'] : oBody;
      setState(() {
        _list = cList is List ? cList : [];
        _orders = oList is List ? oList : [];
      });
    } on DioException catch (e) {
      setState(() {
        _list = [];
        if (e.response?.statusCode != 404) _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final titleCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String? orderId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Claim', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
                const SizedBox(height: 12),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason')),
                const SizedBox(height: 12),
                if (_orders.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: orderId,
                    decoration: const InputDecoration(labelText: 'Order (optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— None —')),
                      ..._orders.map((o) {
                        final m = o as Map;
                        return DropdownMenuItem(
                          value: m['id']?.toString(),
                          child: Text(m['customerName']?.toString() ?? m['id']?.toString() ?? ''),
                        );
                      }),
                    ],
                    onChanged: (v) => setLocal(() => orderId = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        );
      }),
    );

    if (ok != true || titleCtrl.text.trim().isEmpty) return;
    try {
      await ApiClient.instance.dio.post('/claims', data: {
        'title': titleCtrl.text.trim(),
        if (reasonCtrl.text.trim().isNotEmpty) 'reason': reasonCtrl.text.trim(),
        if (orderId != null) 'orderId': orderId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim created')));
        _load();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
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
                    Text('Claims Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Track and resolve customer claims',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Claim'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                  : _list.isEmpty
                      ? const Center(child: Text('No claims yet', style: TextStyle(fontWeight: FontWeight.w600)))
                      : ListView.separated(
                          padding: EdgeInsets.all(isWide ? 24 : 16),
                          itemCount: _list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = _list[i] as Map<String, dynamic>;
                            final status = c['status']?.toString() ?? 'open';
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['title']?.toString() ?? c['reason']?.toString() ?? 'Claim',
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (c['reason'] != null)
                                          Text(c['reason'].toString(),
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status == 'open' ? AppColors.warning : AppColors.success,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}