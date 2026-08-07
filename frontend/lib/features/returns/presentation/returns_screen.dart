import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
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
        ApiClient.instance.dio.get('/returns'),
        ApiClient.instance.dio.get('/orders'),
      ]);
      final rBody = results[0].data;
      final oBody = results[1].data;
      final rList = rBody is Map && rBody['data'] != null ? rBody['data'] : rBody;
      final oList = oBody is Map && oBody['data'] != null ? oBody['data'] : oBody;
      setState(() {
        _list = rList is List ? rList : [];
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
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an order first')),
      );
      return;
    }
    String? orderId = (_orders.first as Map)['id']?.toString();
    final reasonCtrl = TextEditingController(text: 'customer_return');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Return', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: orderId,
                  decoration: const InputDecoration(labelText: 'Order *'),
                  items: _orders.map((o) {
                    final m = o as Map;
                    return DropdownMenuItem(
                      value: m['id']?.toString(),
                      child: Text(m['customerName']?.toString() ?? m['id']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setLocal(() => orderId = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason')),
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

    if (ok != true || orderId == null) return;
    try {
      await ApiClient.instance.dio.post('/returns', data: {
        'orderId': orderId,
        'reason': reasonCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return created')));
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
                    Text('Returns Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Investigate returned shipments',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Return'),
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
                      ? const Center(child: Text('No returns yet', style: TextStyle(fontWeight: FontWeight.w600)))
                      : ListView.separated(
                          padding: EdgeInsets.all(isWide ? 24 : 16),
                          itemCount: _list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _list[i] as Map<String, dynamic>;
                            final status = r['status']?.toString() ?? 'open';
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
                                    child: Text(
                                      r['reason']?.toString() ?? r['id']?.toString() ?? 'Return',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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