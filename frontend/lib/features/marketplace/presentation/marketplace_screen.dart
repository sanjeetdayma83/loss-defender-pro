import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class _Channel {
  final String provider, name, subtitle;
  final IconData icon;
  const _Channel(this.provider, this.name, this.subtitle, this.icon);
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<dynamic> _connections = [];
  bool _loading = true;
  String? _error;

  static const channels = [
    _Channel('amazon', 'Amazon', 'SP-API orders', Icons.shopping_cart_outlined),
    _Channel('flipkart', 'Flipkart', 'Seller API', Icons.storefront_outlined),
    _Channel('meesho', 'Meesho', 'Supplier sync', Icons.local_mall_outlined),
    _Channel('shopify', 'Shopify', 'Store sync', Icons.store_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/marketplace/connections');
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      setState(() {
        _connections = data is List ? data : [];
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
        _connections = [];
      });
    }
  }

  Future<void> _connect(String provider) async {
    try {
      await ApiClient.instance.dio.post('/marketplace/connect', data: {
        'provider': provider,
        'storeName': 'Demo $provider',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$provider connected (stub credentials)')),
        );
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed')),
        );
      }
    }
  }

  Future<void> _sync(String provider) async {
    try {
      final res = await ApiClient.instance.dio.post('/marketplace/sync', data: {'provider': provider});
      final msg = res.data is Map ? (res.data['data']?['message'] ?? res.data['data']?['status']) : 'queued';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Sync failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Marketplace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Connect channels and trigger sync (OAuth keys optional).',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        Text('Connections (${_connections.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_connections.isEmpty)
          const Card(child: ListTile(title: Text('No connections yet'), subtitle: Text('Tap a channel below'))),
        ..._connections.map((c) {
          final m = c is Map ? Map<String, dynamic>.from(c as Map) : <String, dynamic>{};
          return Card(
            child: ListTile(
              title: Text('${m['provider'] ?? m['storeName'] ?? m['id']}'),
              subtitle: Text('status: ${m['status'] ?? '—'}'),
              trailing: TextButton(onPressed: () => _sync('${m['provider'] ?? 'amazon'}'), child: const Text('Sync')),
            ),
          );
        }),
        const SizedBox(height: 20),
        const Text('Add channel', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...channels.map((ch) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withOpacity(0.12),
                  child: Icon(ch.icon, color: AppColors.accent),
                ),
                title: Text(ch.name),
                subtitle: Text(ch.subtitle),
                trailing: const Icon(Icons.add),
                onTap: () => _connect(ch.provider),
              ),
            )),
      ],
    );
  }
}
