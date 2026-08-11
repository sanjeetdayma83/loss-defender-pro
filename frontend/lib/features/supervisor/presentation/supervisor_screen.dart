import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class SupervisorScreen extends StatefulWidget {
  const SupervisorScreen({super.key});
  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  dynamic _live;
  String? _error;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/supervisor/live');
      setState(() {
        _live = res.data is Map ? res.data['data'] ?? res.data : res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Supervisor live'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text('$_live', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
    );
  }
}