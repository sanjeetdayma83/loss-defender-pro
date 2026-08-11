import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});
  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  List<dynamic> _list = [];
  bool _loading = true;
  String? _error;

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
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/stations');
      setState(() { _list = _asList(res.data); _loading = false; });
    } on DioException catch (e) {
      setState(() { _error = e.message ?? 'Failed'; _loading = false; });
    }
  }

  Future<void> _create() async {
    final whRes = await ApiClient.instance.dio.get('/warehouses');
    if (!mounted) return;
    final whs = _asList(whRes.data);
    if (whs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a warehouse first')));
      return;
    }
    final whId = (whs.first as Map)['id']?.toString();
    final nameCtrl = TextEditingController(text: 'Station');
    final codeCtrl = TextEditingController(text: 'ST-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New station'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Station ID')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true || whId == null) return;
    await ApiClient.instance.dio.post('/stations', data: {
      'warehouseId': whId,
      'stationName': nameCtrl.text.trim(),
      'stationId': codeCtrl.text.trim(),
      'status': 'online',
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            const Text('Stations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _list.isEmpty
                      ? const Center(child: Text('No stations'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = Map<String, dynamic>.from(_list[i] as Map);
                            final wh = s['warehouse'];
                            return ListTile(
                              tileColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                              title: Text('${s['stationName'] ?? ''} (${s['stationId'] ?? ''})'),
                              subtitle: Text('${wh is Map ? wh['name'] : ''} · ${s['status'] ?? ''}'),
                              leading: Icon(Icons.desktop_windows, color: (s['status']?.toString() == 'online') ? Colors.green : Colors.grey),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}