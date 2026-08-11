import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'recording_session_page.dart';
import 'recording_detail_page.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});
  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  List<dynamic> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/recordings');
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      setState(() => _list = data is List ? data : []);
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.length > 19) return s.substring(0, 19).replaceAll('T', ' ');
    return s;
  }

  Future<void> _startWithPicker() async {
    String? orderId;
    String? warehouseId;
    List<Map<String, dynamic>> orders = [];
    List<Map<String, dynamic>> warehouses = [];

    try {
      final oRes = await ApiClient.instance.dio.get('/orders');
      final oBody = oRes.data;
      final oData = oBody is Map && oBody['data'] != null ? oBody['data'] : oBody;
      orders = (oData is List ? oData : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final wRes = await ApiClient.instance.dio.get('/warehouses');
      final wBody = wRes.data;
      final wData = wBody is Map && wBody['data'] != null ? wBody['data'] : wBody;
      warehouses = (wData is List ? wData : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
      return;
    }

    if (!mounted) return;
    if (orders.isEmpty || warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 1 order and 1 warehouse')),
      );
      return;
    }

    orderId = orders.first['id']?.toString();
    warehouseId = warehouses.first['id']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Start recording'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: orderId,
                      decoration: const InputDecoration(labelText: 'Order', border: OutlineInputBorder()),
                      items: orders
                          .map((o) => DropdownMenuItem(
                                value: o['id']?.toString(),
                                child: Text(
                                  '${o['customerName'] ?? o['id']} · ${o['status'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setLocal(() => orderId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: warehouseId,
                      decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
                      items: warehouses
                          .map((w) => DropdownMenuItem(
                                value: w['id']?.toString(),
                                child: Text(w['name']?.toString() ?? w['id']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setLocal(() => warehouseId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
              ],
            );
          },
        );
      },
    );

    if (ok != true || orderId == null || warehouseId == null) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordingSessionPage(orderId: orderId, warehouseId: warehouseId),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final completed = _list.where((r) => r['status'] == 'completed' || r['status'] == 'ready').length;
    final active = _list.where((r) {
      final s = r['status']?.toString();
      return s == 'started' || s == 'recording';
    }).length;

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
                    Text('Recordings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Pick order + warehouse, then record',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _startWithPicker,
                icon: const Icon(Icons.videocam, size: 18),
                label: const Text('Start Recording'),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 12, isWide ? 24 : 16, 8),
          child: Text('Active $active · Done $completed · Total ${_list.length}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _list.isEmpty
                      ? const Center(child: Text('No recordings yet'))
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 0, isWide ? 24 : 16, 24),
                          itemCount: _list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = _list[i] is Map ? Map<String, dynamic>.from(_list[i] as Map) : <String, dynamic>{};
                            final id = r['id']?.toString() ?? '';
                            return Card(
                              child: ListTile(
                                title: Text('Recording ${id.length > 8 ? id.substring(0, 8) : id}'),
                                subtitle: Text('${r['status']} · ${_fmt(r['createdAt'])} · ${r['durationSec'] ?? '—'}s'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: id.isEmpty
                                    ? null
                                    : () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RecordingDetailPage(recordingId: id),
                                          ),
                                        );
                                        _load();
                                      },
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
