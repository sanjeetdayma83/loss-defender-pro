import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<dynamic> _plans = [];
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
      final p = plansRes.data is Map && plansRes.data['data'] != null
          ? plansRes.data['data'] : plansRes.data;
      final s = subRes.data is Map && subRes.data['data'] != null
          ? subRes.data['data'] : subRes.data;
      setState(() {
        _plans = p is List ? p : [];
        _sub = s is Map ? Map<String, dynamic>.from(s as Map) : null;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  Future<void> _choose(String planId) async {
    try {
      await ApiClient.instance.dio.patch('/billing/subscription', data: {'plan': planId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan set to $planId (no payment provider)')),
        );
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _sub?['plan']?.toString() ?? 'free';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Plans & Billing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Current plan: $plan', style: const TextStyle(color: AppColors.textSecondary)),
        if (_sub != null) ...[
          const SizedBox(height: 8),
          Text('Storage: ${_sub!['storageUsed'] ?? '—'} / ${_sub!['storageQuota'] ?? '—'}',
              style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        LayoutBuilder(builder: (context, c) {
          final cross = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: _plans.length,
            itemBuilder: (_, i) {
              final p = _plans[i] is Map ? Map<String, dynamic>.from(_plans[i] as Map) : <String, dynamic>{};
              final id = p['id']?.toString() ?? '';
              final isCurrent = id == plan;
              return Card(
                elevation: isCurrent ? 3 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name']?.toString() ?? id,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Quota: ${p['storageQuota'] ?? '—'}', style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isCurrent ? null : () => _choose(id),
                          child: Text(isCurrent ? 'Current Plan' : 'Choose Plan'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 12),
        const Text('Payment provider (Razorpay/Stripe) not wired — plan field only.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
