import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/config/feature_flags.dart';

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
    // Check if provider is enabled via feature flags
    final providerEnabled = isFeatureEnabled('marketplace.$provider');
    if (!providerEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$provider is not available: ${getFeatureInfo('marketplace.$provider')?['reason'] ?? 'Feature disabled'}')),
        );
      }
      return;
    }
    final storeCtrl = TextEditingController(text: 'My $provider Store');
    final webhookCtrl = TextEditingController();
    final accessCtrl = TextEditingController();
    final refreshCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: Text('Connect $provider', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: 'Store Name *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: webhookCtrl, decoration: const InputDecoration(labelText: 'Webhook Secret (for HMAC)', border: OutlineInputBorder(), helperText: 'Configure in provider dashboard')),
                const SizedBox(height: 12),
                TextField(controller: accessCtrl, decoration: const InputDecoration(labelText: 'Access Token (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: refreshCtrl, decoration: const InputDecoration(labelText: 'Refresh Token (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                Text('Webhook URL: https://your-domain.com/api/v1/marketplace/webhooks/$provider', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const Text('Header: X-Webhook-Secret or X-Signature', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Connect')),
        ],
      )),
    );

    if (ok != true) return;
    try {
      await ApiClient.instance.dio.post('/marketplace/connect', data: {
        'provider': provider,
        'storeName': storeCtrl.text.trim(),
        if (webhookCtrl.text.trim().isNotEmpty) 'webhookSecret': webhookCtrl.text.trim(),
        if (accessCtrl.text.trim().isNotEmpty) 'accessToken': accessCtrl.text.trim(),
        if (refreshCtrl.text.trim().isNotEmpty) 'refreshToken': refreshCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$provider connected')));
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Sync failed')));
      }
    }
  }

  Future<void> _disconnect(Map<String, dynamic> conn) async {
    final confirm = await AppDialogs.confirm(context, title: 'Disconnect?', message: 'This will remove the connection and credentials.');
    if (confirm != true) return;
    try {
      await ApiClient.instance.dio.delete('/marketplace/connections/${conn['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected')));
        _load();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed')));
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
        const Text('Connect channels and trigger sync. Webhook HMAC verification enabled.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        Text('Connections (${_connections.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_connections.isEmpty)
          const Card(child: ListTile(title: Text('No connections yet'), subtitle: Text('Tap a channel below to connect')))
        else
          ..._connections.map((c) {
            final m = c is Map ? Map<String, dynamic>.from(c as Map) : <String, dynamic>{};
            final hasWebhook = m['webhookSecret'] != null;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withOpacity(0.12),
                  child: Icon(
                    m['provider'] == 'amazon' ? Icons.shopping_cart :
                    m['provider'] == 'flipkart' ? Icons.storefront :
                    m['provider'] == 'meesho' ? Icons.local_mall : Icons.store,
                    color: AppColors.accent,
                  ),
                ),
                title: Text('${m['provider']?.toString().toUpperCase() ?? 'UNKNOWN'} - ${m['storeName'] ?? m['id']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${m['status'] ?? '—'}'),
                    Row(
                      children: [
                        Icon(hasWebhook ? Icons.verified : Icons.warning_amber, size: 14, color: hasWebhook ? Colors.green : Colors.orange),
                        const SizedBox(width: 4),
                        Text(hasWebhook ? 'HMAC verified' : 'No webhook secret', style: TextStyle(fontSize: 11, color: hasWebhook ? Colors.green : Colors.orange)),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () => _sync('${m['provider'] ?? 'amazon'}'), child: const Text('Sync')),
                    const SizedBox(width: 4),
                    TextButton(onPressed: () => _disconnect(m), child: const Text('Disconnect', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        const Text('Add channel', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...channels
            .where((ch) => isFeatureEnabled('marketplace.${ch.provider}'))
            .map((ch) => Card(
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