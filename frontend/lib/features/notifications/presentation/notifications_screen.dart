import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _list = [];
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
      final res = await ApiClient.instance.dio.get('/notifications');
      setState(() { _list = _asList(res.data); _loading = false; });
    } catch (_) {
      setState(() { _list = []; _loading = false; });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await ApiClient.instance.dio.patch('/notifications/$id/read');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Notifications'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final n = Map<String, dynamic>.from(_list[i] as Map);
                    final id = n['id']?.toString() ?? '';
                    return ListTile(
                      title: Text(n['title']?.toString() ?? n['message']?.toString() ?? 'Notification'),
                      subtitle: Text(n['createdAt']?.toString() ?? ''),
                      trailing: n['readAt'] == null && id.isNotEmpty
                          ? TextButton(onPressed: () => _markRead(id), child: const Text('Read'))
                          : null,
                    );
                  },
                ),
    );
  }
}