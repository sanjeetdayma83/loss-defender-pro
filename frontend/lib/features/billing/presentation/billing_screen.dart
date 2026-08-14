import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/feature_flags.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  Map<String, dynamic>? _catalog;
  Map<String, dynamic>? _sub;
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
      final plansRes = await ApiClient.instance.dio.get('/billing/plans');
      final subRes = await ApiClient.instance.dio.get('/billing/subscription');
      final cat = plansRes.data is Map && plansRes.data['data'] != null ? plansRes.data['data'] : plansRes.data;
      final sub = subRes.data is Map && subRes.data['data'] != null ? subRes.data['data'] : subRes.data;
      setState(() {
        _catalog = cat is Map ? Map<String, dynamic>.from(cat as Map) : {};
        _sub = sub is Map ? Map<String, dynamic>.from(sub as Map) : {};
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  Future<void> _checkout(String planId) async {
    try {
      final res = await ApiClient.instance.dio.post('/billing/checkout/plan', data: {'planId': planId});
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      final order = data is Map ? data['order'] : null;
      if (!mounted) return;
      final configured = order is Map && order['configured'] == true;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(configured ? 'Razorpay order' : 'Checkout (keys not set)'),
          content: Text(
            configured
                ? 'Order: ${order['id']}\nAmount paise: ${order['amount']}\nOpen Razorpay Checkout with KEY + order id.'
                : 'RAZORPAY_KEY_ID not set. Mock order: ${order is Map ? order['id'] : order}\nAdd keys in backend .env then retry.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      // Live: integrate razorpay_flutter with order['id'] + order['keyId']
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Checkout failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide billing if feature is disabled
    final billingEnabled = isFeatureEnabled('billing.enabled');
    if (!billingEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('Billing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              FeatureFlags.getFeatureInfo('billing.enabled')?['reason'] ?? 'Billing feature is not available',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final plans = (_catalog?['plans'] is List) ? _catalog!['plans'] as List : [];
    final packs = (_catalog?['scanPacks'] is List) ? _catalog!['scanPacks'] as List : [];
    final current = _sub?['plan']?.toString() ?? 'free';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Choose Your Plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('Current: $current · Razorpay: ${_catalog?['razorpayConfigured'] == true ? 'live' : 'keys pending'}',
            style: const TextStyle(color: AppColors.textSecondary)),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ...plans.map((raw) {
          final p = raw is Map ? Map<String, dynamic>.from(raw as Map) : <String, dynamic>{};
          final id = p['id']?.toString() ?? '';
          final features = p['features'] is List ? p['features'] as List : [];
          final isCurrent = id == current;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name']?.toString() ?? id, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('₹${p['priceInr']} / ${p['intervalMonths']} months (₹${p['pricePerMonthInr']}/mo)',
                      style: const TextStyle(fontSize: 16, color: AppColors.accent)),
                  Text('${p['scans']} scans · ${p['validityDays']} days validity · ${p['videoRetentionDays']} days video',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(child: Text('$f', style: const TextStyle(fontSize: 13))),
                        ]),
                      )),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isCurrent ? null : () => _checkout(id),
                      child: Text(isCurrent ? 'Current Plan' : 'Choose Plan — Pay with Razorpay'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text('Overage scan packs', style: TextStyle(fontWeight: FontWeight.w600)),
        ...packs.map((raw) {
          final p = raw is Map ? Map<String, dynamic>.from(raw as Map) : <String, dynamic>{};
          return ListTile(
            title: Text('${p['scans']} scans'),
            trailing: Text('₹${p['priceInr']}'),
            subtitle: Text(p['id']?.toString() ?? ''),
          );
        }),
        const SizedBox(height: 12),
        const Text('Payments secured by Razorpay. Keys: RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET in backend .env',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
