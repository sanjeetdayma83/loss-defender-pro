import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _tab = 'ready';
  Map<String, dynamic>? _selected;
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<dynamic> _asList(dynamic body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is List) return body;
    return [];
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/orders');
      setState(() {
        _orders = _asList(res.data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed';
        _loading = false;
      });
    }
  }

  bool _isReady(String s) =>
      ['scanned', 'evidence_ready', 'packing', 'recording', 'queued'].contains(s);
  bool _isDispatched(String s) => s == 'dispatched';
  bool _isShipped(String s) => s == 'shipped' || s == 'closed';
  bool _isException(String s) =>
      ['claimed', 'returned', 'failed', 'exception'].contains(s);

  List<dynamic> get _filtered {
    var list = _orders.where((o) {
      if (o is! Map) return false;
      final s = (o['status']?.toString() ?? '').toLowerCase();
      switch (_tab) {
        case 'ready':
          return _isReady(s);
        case 'dispatched':
          return _isDispatched(s);
        case 'transit':
          return s == 'shipped';
        case 'exceptions':
          return _isException(s);
        default:
          return true;
      }
    }).toList();
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      list = list.where((o) {
        final m = o as Map;
        return '${m['marketplaceOrderId']} ${m['awb']} ${m['id']}'
            .toLowerCase()
            .contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _markDispatched(Map o) async {
    final awbCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Dispatched'),
        content: TextField(
          controller: awbCtrl,
          decoration: const InputDecoration(
            labelText: 'AWB / Tracking No. *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || awbCtrl.text.trim().isEmpty) return;
    final id = o['id']?.toString();
    if (id == null) return;
    try {
      // Prefer dedicated dispatch endpoint if exists; else patch status
      try {
        await ApiClient.instance.dio.post('/orders/$id/dispatch', data: {
          'awb': awbCtrl.text.trim(),
        });
      } catch (_) {
        await ApiClient.instance.dio.patch('/orders/$id', data: {
          'status': 'dispatched',
          'awb': awbCtrl.text.trim(),
        });
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as dispatched')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final ready = _orders.where((o) =>
        o is Map && _isReady((o['status']?.toString() ?? '').toLowerCase())).length;
    final dispatched = _orders.where((o) =>
        o is Map && _isDispatched((o['status']?.toString() ?? '').toLowerCase())).length;
    final transit = _orders.where((o) =>
        o is Map && (o['status']?.toString() ?? '') == 'shipped').length;
    final exceptions = _orders.where((o) =>
        o is Map && _isException((o['status']?.toString() ?? '').toLowerCase())).length;
    final filtered = _filtered;

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
                    Text('Dispatch Center',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Manage outbound shipments, verify dispatch and track handover.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: LayoutBuilder(builder: (context, c) {
            final cross = c.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                _Kpi('Ready to Dispatch', '$ready', Icons.inventory_2, const Color(0xFF3B82F6)),
                _Kpi('Dispatched', '$dispatched', Icons.local_shipping, const Color(0xFF22C55E)),
                _Kpi('In Transit', '$transit', Icons.flight_takeoff, const Color(0xFF8B5CF6)),
                _Kpi('Exceptions', '$exceptions', Icons.warning_amber, const Color(0xFFEF4444)),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search by Order ID, AWB…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTab('Ready ($ready)', 'ready'),
                _buildTab('Dispatched ($dispatched)', 'dispatched'),
                _buildTab('In Transit ($transit)', 'transit'),
                _buildTab('Exceptions ($exceptions)', 'exceptions'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                  : isWide
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: _list(filtered)),
                            SizedBox(width: 300, child: _detail()),
                          ],
                        )
                      : _list(filtered),
        ),
      ],
    );
  }

  Widget _buildTab(String label, String key) {
    final sel = _tab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: sel ? const Color(0xFF2563EB) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? const Color(0xFF2563EB) : AppColors.textSecondary,
              )),
        ),
      ),
    );
  }

  Widget _list(List<dynamic> filtered) {
    if (filtered.isEmpty) {
      return const Center(child: Text('No orders in this queue'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final o = filtered[i] as Map<String, dynamic>;
        final status = o['status']?.toString() ?? '';
        final id = o['marketplaceOrderId']?.toString() ?? o['id']?.toString() ?? '—';
        final awb = o['awb']?.toString() ?? '—';
        final sel = _selected?['id'] == o['id'];
        return InkWell(
          onTap: () => setState(() => _selected = o),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? const Color(0xFF2563EB) : AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(id,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF2563EB))),
                ),
                Expanded(
                  child: Text(awb, style: const TextStyle(fontSize: 12)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB))),
                ),
                const SizedBox(width: 8),
                if (_isReady(status.toLowerCase()))
                  IconButton(
                    icon: const Icon(Icons.local_shipping_outlined, size: 20),
                    tooltip: 'Dispatch',
                    onPressed: () => _markDispatched(o),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detail() {
    final o = _selected;
    if (o == null) {
      return Container(
        margin: const EdgeInsets.only(right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
            child: Text('Select an order',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    final status = (o['status']?.toString() ?? '').toLowerCase();
    return Container(
      margin: const EdgeInsets.only(right: 24, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(
        children: [
          const Text('Dispatch Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          _row('Order ID',
              o['marketplaceOrderId']?.toString() ?? o['id']?.toString() ?? '—'),
          _row('Status', o['status']?.toString() ?? '—'),
          _row('AWB', o['awb']?.toString() ?? '—'),
          _row('Warehouse', o['warehouseId']?.toString() ?? '—'),
          const SizedBox(height: 16),
          if (_isReady(status))
            FilledButton.icon(
              onPressed: () => _markDispatched(o),
              icon: const Icon(Icons.check),
              label: const Text('Mark as Dispatched'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Kpi extends StatelessWidget {
  final String t, v;
  final IconData i;
  final Color c;
  const _Kpi(this.t, this.v, this.i, this.c);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(v,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(t,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}