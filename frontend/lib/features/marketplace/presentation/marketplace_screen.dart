import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<dynamic> _conn = [];
  String? _syncMsg;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  List<dynamic> _asList(dynamic body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is List) return body;
    return [];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/marketplace/connections');
      setState(() { _conn = _asList(res.data); _loading = false; });
    } catch (_) {
      setState(() { _conn = []; _loading = false; });
    }
  }

  Future<void> _sync() async {
    try {
      final res = await ApiClient.instance.dio.post('/marketplace/sync', data: {'provider': 'amazon'});
      final d = res.data is Map ? res.data['data'] ?? res.data : res.data;
      setState(() => _syncMsg = d.toString());
    } catch (e) {
      setState(() => _syncMsg = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Marketplace'), actions: [
        TextButton(onPressed: _sync, child: const Text('Sync (stub)')),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_syncMsg != null) Text(_syncMsg!, style: const TextStyle(fontSize: 12)),
              if (_conn.isEmpty) const Text('No connections — OAuth not configured yet'),
              ..._conn.map((c) {
                final m = Map<String, dynamic>.from(c as Map);
                return ListTile(title: Text('${m['provider'] ?? m['storeName'] ?? m}'));
              }),
            ]),
    );
  }
}