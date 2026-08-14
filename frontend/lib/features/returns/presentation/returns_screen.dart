import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  List<dynamic> _list = [];
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _tab = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.instance.dio.get('/returns'),
        ApiClient.instance.dio.get('/orders'),
      ]);
      final rBody = results[0].data;
      final oBody = results[1].data;
      final rList = rBody is Map && rBody['data'] != null ? rBody['data'] : rBody;
      final oList = oBody is Map && oBody['data'] != null ? oBody['data'] : oBody;
      setState(() {
        _list = rList is List ? rList : [];
        _orders = oList is List ? oList : [];
      });
    } on DioException catch (e) {
      setState(() {
        _list = [];
        if (e.response?.statusCode != 404) _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    var list = _list;
    switch (_tab) {
      case 'requested':
        return list.where((r) => (r['status']?.toString() ?? 'requested') == 'requested').toList();
      case 'received':
        return list.where((r) => (r['status']?.toString() ?? '') == 'received').toList();
      case 'inspecting':
        return list.where((r) => (r['status']?.toString() ?? '') == 'inspecting').toList();
      case 'refunded':
        return list.where((r) => (r['status']?.toString() ?? '') == 'refunded').toList();
      case 'restocked':
        return list.where((r) => (r['status']?.toString() ?? '') == 'restocked').toList();
      case 'rejected':
        return list.where((r) => (r['status']?.toString() ?? '') == 'rejected').toList();
      case 'closed':
        return list.where((r) => (r['status']?.toString() ?? '') == 'closed').toList();
      default:
        return list;
    }
  }

  Future<void> _create() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create an order first')));
      return;
    }
    String? orderId = (_orders.first as Map)['id']?.toString();
    final reasonCtrl = TextEditingController(text: 'customer_return');
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Return', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: orderId,
                  decoration: const InputDecoration(labelText: 'Order *', border: OutlineInputBorder()),
                  items: _orders.map((o) {
                    final m = o as Map;
                    return DropdownMenuItem<String>(
                      value: m['id']?.toString(),
                      child: Text(m['customerName']?.toString() ?? m['id']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setLocal(() => orderId = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        );
      }),
    );

    if (ok != true || orderId == null) return;
    try {
      await ApiClient.instance.dio.post('/returns', data: {
        'orderId': orderId,
        'reason': reasonCtrl.text.trim(),
        if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return created')));
        _load();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> returnItem, String newStatus) async {
    try {
      await ApiClient.instance.dio.patch('/returns/${returnItem['id']}', data: {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Return $newStatus')));
        _load();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed'), backgroundColor: AppColors.danger));
      }
    }
  }

  void _showStatusDialog(Map<String, dynamic> returnItem) {
    final currentStatus = returnItem['status']?.toString() ?? 'requested';
    final allowed = {
      'requested': ['received', 'rejected', 'closed'],
      'received': ['inspecting', 'rejected', 'closed'],
      'inspecting': ['refunded', 'restocked', 'rejected', 'closed'],
      'refunded': ['closed'],
      'restocked': ['closed'],
      'rejected': ['closed'],
      'closed': [],
    }[currentStatus] ?? [];

    String? selectedStatus;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Update Return Status', style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current: $currentStatus', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (allowed.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'New Status *', border: OutlineInputBorder()),
                    items: allowed.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setLocal(() => selectedStatus = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedStatus == null ? null : () {
                Navigator.pop(ctx);
                _updateStatus(returnItem, selectedStatus!);
              },
              child: const Text('Update'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final filtered = _filtered;
    final requestedCount = _list.where((r) => (r['status']?.toString() ?? 'requested') == 'requested').length;
    final receivedCount = _list.where((r) => (r['status']?.toString() ?? '') == 'received').length;
    final inspectingCount = _list.where((r) => (r['status']?.toString() ?? '') == 'inspecting').length;
    final refundedCount = _list.where((r) => (r['status']?.toString() ?? '') == 'refunded').length;
    final restockedCount = _list.where((r) => (r['status']?.toString() ?? '') == 'restocked').length;
    final rejectedCount = _list.where((r) => (r['status']?.toString() ?? '') == 'rejected').length;
    final closedCount = _list.where((r) => (r['status']?.toString() ?? '') == 'closed').length;

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
                    Text('Returns Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Investigate returned shipments', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
              const SizedBox(width: 4),
              FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add, size: 18), label: const Text('New Return')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabChip('All (${_list.length})', 'all'),
                _TabChip('Requested ($requestedCount)', 'requested'),
                _TabChip('Received ($receivedCount)', 'received'),
                _TabChip('Inspecting ($inspectingCount)', 'inspecting'),
                _TabChip('Refunded ($refundedCount)', 'refunded'),
                _TabChip('Restocked ($restockedCount)', 'restocked'),
                _TabChip('Rejected ($rejectedCount)', 'rejected'),
                _TabChip('Closed ($closedCount)', 'closed'),
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
                      ? const Center(child: Text('No returns yet', style: TextStyle(fontWeight: FontWeight.w600)))
                      : ListView.separated(
                          padding: EdgeInsets.all(isWide ? 24 : 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = filtered[i] as Map<String, dynamic>;
                            final status = r['status']?.toString() ?? 'requested';
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r['reason']?.toString() ?? r['id']?.toString() ?? 'Return', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (r['notes'] != null) Text(r['notes'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        if (r['orderId'] != null) Text('Order: ${r['orderId']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status == 'requested' ? AppColors.warning : (status == 'rejected' || status == 'closed' ? AppColors.danger : (status == 'refunded' || status == 'restocked' ? AppColors.success : AppColors.accent)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showStatusDialog(r), tooltip: 'Update Status'),
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
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sel ? const Color(0xFF2563EB) : Colors.transparent, width: 2))),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF2563EB) : AppColors.textSecondary)),
        ),
      ),
    );
  }
}