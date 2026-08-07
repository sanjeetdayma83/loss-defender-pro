import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _all = [];
  bool _loading = true;
  String? _error;
  String _tab = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

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
    if (body is Map && body['data'] is Map) {
      final d = body['data'] as Map;
      if (d['items'] is List) return d['items'] as List;
    }
    if (body is List) return body;
    return [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/orders');
      setState(() {
        _all = _asList(res.data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    var list = _all;
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        if (o is! Map) return false;
        final id = '${o['marketplaceOrderId'] ?? ''} ${o['id'] ?? ''} ${o['awb'] ?? ''}'.toLowerCase();
        final cust = '${o['customer'] ?? ''}'.toLowerCase();
        return id.contains(q) || cust.contains(q);
      }).toList();
    }
    switch (_tab) {
      case 'pending':
        return list.where((o) {
          final s = (o is Map ? o['status']?.toString() : '')?.toLowerCase() ?? '';
          return ['synced', 'queued', 'pending'].contains(s);
        }).toList();
      case 'progress':
        return list.where((o) {
          final s = (o is Map ? o['status']?.toString() : '')?.toLowerCase() ?? '';
          return ['packing', 'recording', 'scanned', 'evidence_ready'].contains(s);
        }).toList();
      case 'completed':
        return list.where((o) {
          final s = (o is Map ? o['status']?.toString() : '')?.toLowerCase() ?? '';
          return ['dispatched', 'shipped', 'closed', 'verified'].contains(s);
        }).toList();
      case 'exceptions':
        return list.where((o) {
          final s = (o is Map ? o['status']?.toString() : '')?.toLowerCase() ?? '';
          return ['claimed', 'returned', 'failed', 'exception'].contains(s);
        }).toList();
      default:
        return list;
    }
  }

  int _countWhere(bool Function(String status) test) {
    return _all.where((o) {
      final s = (o is Map ? o['status']?.toString() : '')?.toLowerCase() ?? '';
      return test(s);
    }).length;
  }

  Future<void> _createOrder() async {
    final orderCtrl = TextEditingController();
    final skuCtrl = TextEditingController(text: 'SKU-001');
    final qtyCtrl = TextEditingController(text: '1');
    final nameCtrl = TextEditingController(text: 'Sample Item');
    List<dynamic> warehouses = [];
    String? warehouseId;

    try {
      final res = await ApiClient.instance.dio.get('/warehouses');
      warehouses = _asList(res.data);
      if (warehouses.isNotEmpty && warehouses.first is Map) {
        warehouseId = (warehouses.first as Map)['id']?.toString();
      }
    } catch (_) {}

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('New Order'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: orderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marketplace Order ID *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: warehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final w in warehouses)
                          if (w is Map)
                            DropdownMenuItem(
                              value: w['id']?.toString(),
                              child: Text(w['name']?.toString() ?? '—'),
                            ),
                      ],
                      onChanged: (v) => setLocal(() => warehouseId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: skuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SKU *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create')),
            ],
          );
        });
      },
    );

    if (ok != true) return;
    if (orderCtrl.text.trim().isEmpty || skuCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order ID and SKU required')),
        );
      }
      return;
    }

    try {
      await ApiClient.instance.dio.post('/orders', data: {
        'marketplace': 'manual',
        'marketplaceOrderId': orderCtrl.text.trim(),
        if (warehouseId != null) 'warehouseId': warehouseId,
        'items': [
          {
            'sku': skuCtrl.text.trim(),
            'qty': int.tryParse(qtyCtrl.text) ?? 1,
            'name': nameCtrl.text.trim().isEmpty
                ? skuCtrl.text.trim()
                : nameCtrl.text.trim(),
          }
        ],
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order created')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.response?.data?.toString() ??
                  e.message ??
                  'Create failed')),
        );
      }
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'dispatched':
      case 'shipped':
      case 'closed':
      case 'verified':
      case 'scanned':
        return const Color(0xFF22C55E);
      case 'packing':
      case 'recording':
      case 'queued':
      case 'synced':
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'claimed':
      case 'returned':
      case 'failed':
      case 'exception':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')} ${_m(d.month)} ${d.year}\n'
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _m(int m) {
    const a = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return a[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final filtered = _filtered;
    final total = _all.length;
    final verified = _countWhere((s) =>
        ['dispatched', 'shipped', 'closed', 'verified', 'scanned'].contains(s));
    final pending = _countWhere(
        (s) => ['synced', 'queued', 'pending'].contains(s));
    final exceptions = _countWhere(
        (s) => ['claimed', 'returned', 'failed', 'exception'].contains(s));
    final shipped = _countWhere((s) => s == 'shipped' || s == 'dispatched');

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
                    Text('Orders',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Manage and track all inbound and outbound orders.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _createOrder,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Order'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // KPIs
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: LayoutBuilder(builder: (context, c) {
            final cross = c.maxWidth > 900 ? 5 : c.maxWidth > 600 ? 3 : 2;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _Kpi('Total Orders', '$total', Icons.receipt_long,
                    const Color(0xFF3B82F6)),
                _Kpi('Verified', '$verified', Icons.verified,
                    const Color(0xFF22C55E)),
                _Kpi('Pending', '$pending', Icons.hourglass_empty,
                    const Color(0xFFF59E0B)),
                _Kpi('Exceptions', '$exceptions', Icons.warning_amber,
                    const Color(0xFFEF4444)),
                _Kpi('Shipped', '$shipped', Icons.local_shipping,
                    const Color(0xFF8B5CF6)),
              ],
            );
          }),
        ),
        const SizedBox(height: 16),
        // Search
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search by Order ID, Tracking, AWB…',
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Tabs
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabChip('All Orders ($total)', 'all'),
                _TabChip('Pending ($pending)', 'pending'),
                _TabChip(
                    'In Progress (${_countWhere((s) => ['packing', 'recording', 'scanned'].contains(s))})',
                    'progress'),
                _TabChip('Completed ($verified)', 'completed'),
                _TabChip('Exceptions ($exceptions)', 'exceptions'),
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
                  : filtered.isEmpty
                      ? const Center(child: Text('No orders'))
                      : ListView.separated(
                          padding: EdgeInsets.all(isWide ? 24 : 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final o = filtered[i] as Map<String, dynamic>;
                            final status = o['status']?.toString() ?? '';
                            final orderId = o['marketplaceOrderId']?.toString() ??
                                o['id']?.toString() ??
                                '—';
                            final awb = o['awb']?.toString() ??
                                o['trackingNumber']?.toString() ??
                                '—';
                            final wh = o['warehouse'];
                            final whName = wh is Map
                                ? wh['name']?.toString()
                                : o['warehouseId']?.toString();
                            final sc = _statusColor(status);

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(orderId,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF2563EB))),
                                  ),
                                  if (isWide)
                                    Expanded(
                                      flex: 2,
                                      child: Text(awb,
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                  if (isWide)
                                    Expanded(
                                      flex: 2,
                                      child: Text(whName ?? '—',
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: sc.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: sc)),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 90,
                                    child: Text(_fmtDate(o['createdAt']?.toString()),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 18),
                                    onPressed: () {
                                      AppDialogs.info(context,
                                          title: orderId,
                                          message:
                                              'Status: $status\nAWB: $awb\nWarehouse: ${whName ?? '—'}');
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _TabChip(String label, String key) {
    final sel = _tab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _tab = key),
        borderRadius: BorderRadius.circular(8),
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
                        fontSize: 20, fontWeight: FontWeight.w800)),
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