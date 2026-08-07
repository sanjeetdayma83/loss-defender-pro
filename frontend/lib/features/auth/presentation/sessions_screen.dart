import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<dynamic> _list = [];
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
      final res = await ApiClient.instance.dio.get('/auth/sessions');
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      setState(() { _list = data is List ? data : []; _loading = false; });
    } on DioException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _logoutAll() async {
    await ApiClient.instance.dio.post('/auth/logout-all', data: {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All sessions revoked')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton(onPressed: _logoutAll, child: const Text('Revoke all')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _list[i] as Map;
                    return ListTile(
                      title: Text((s['userAgent'] ?? 'Device').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${s['ipAddress'] ?? ''} · ${s['createdAt'] ?? ''}'),
                    );
                  },
                ),
    );
  }
}