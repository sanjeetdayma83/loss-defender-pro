import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  dynamic _plans;
  dynamic _sub;
  String? _error;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await ApiClient.instance.dio.get('/billing/plans');
      final s = await ApiClient.instance.dio.get('/billing/subscription');
      setState(() {
        _plans = p.data is Map ? p.data['data'] ?? p.data : p.data;
        _sub = s.data is Map ? s.data['data'] ?? s.data : s.data;
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
      appBar: AppBar(title: const Text('Billing & plans')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Current', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${_sub ?? '—'}'),
                  const Divider(height: 32),
                  Text('Plans', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('$_plans'),
                ]),
    );
  }
}