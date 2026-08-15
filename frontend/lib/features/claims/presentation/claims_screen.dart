import '../../../core/widgets/ui_kit.dart'
    show StatusBadge;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});
  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
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
        ApiClient.instance.dio.get('/claims'),
        ApiClient.instance.dio.get('/orders'),
      ]);
      final cBody = results[0].data;
      final oBody = results[1].data;
      final cList = cBody is Map && cBody['data'] != null ? cBody['data'] : cBody;
      final oList = oBody is Map && oBody['data'] != null ? oBody['data'] : oBody;
      setState(() {
        _list = cList is List ? cList : [];
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
      case 'open':
        return list.where((c) => (c['status']?.toString() ?? 'open') == 'open').toList();
      case 'under_review':
        return list.where((c) => (c['status']?.toString() ?? '') == 'under_review').toList();
      case 'approved':
        return list.where((c) => (c['status']?.toString() ?? '') == 'approved').toList();
      case 'rejected':
        return list.where((c) => (c['status']?.toString() ?? '') == 'rejected').toList();
      case 'closed':
        return list.where((c) => (c['status']?.toString() ?? '') == 'closed').toList();
      default:
        return list;
    }
  }

  Future<void> _create() async {
    final reasonCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    String? orderId;
    String? marketplace;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Claim', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_orders.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: orderId,
                    decoration: const InputDecoration(labelText: 'Order *', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('— Select Order —')),
                      ..._orders.map((o) {
                        final m = o as Map;
                        return DropdownMenuItem<String>(
                          value: m['id']?.toString(),
                          child: Text('${m['marketplaceOrderId'] ?? m['customerName'] ?? m['id']}'),
                        );
                      }),
                    ],
                    onChanged: (v) => setLocal(() => orderId = v),
                    validator: (v) => v == null ? 'Order is required' : null,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setLocal(() => marketplace = v),
                  decoration: const InputDecoration(labelText: 'Marketplace (optional)', border: OutlineInputBorder()),
                ),
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

    if (ok != true || reasonCtrl.text.trim().isEmpty || orderId == null) {
      if (orderId == null && ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order is required')));
      }
      return;
    }

    try {
      await ApiClient.instance.dio.post('/claims', data: {
        'orderId': orderId,
        'reason': reasonCtrl.text.trim(),
        if (descriptionCtrl.text.trim().isNotEmpty) 'description': descriptionCtrl.text.trim(),
        if (marketplace != null && marketplace!.isNotEmpty) 'marketplace': marketplace,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim created')));
        _load();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> claim, String newStatus, {String? decisionNote}) async {
    try {
      await ApiClient.instance.dio.patch('/claims/${claim['id']}', data: {
        'status': newStatus,
        if (decisionNote != null) 'decisionNote': decisionNote,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim $newStatus')));
        _load();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showStatusDialog(Map<String, dynamic> claim) {
    final currentStatus = claim['status']?.toString() ?? 'open';
    final allowed = {
      'open': ['under_review', 'approved', 'rejected', 'closed'],
      'under_review': ['approved', 'rejected', 'closed'],
      'approved': ['closed'],
      'rejected': ['closed'],
      'closed': [],
      'pending': ['under_review', 'approved', 'rejected', 'closed'],
    }[currentStatus] ?? [];

    final decisionCtrl = TextEditingController();
    String? selectedStatus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Update Claim Status', style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
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
                const SizedBox(height: 12),
                TextField(
                  controller: decisionCtrl,
                  decoration: const InputDecoration(labelText: 'Decision Note (optional)', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedStatus == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _updateStatus(claim, selectedStatus!, decisionNote: decisionCtrl.text.trim().isNotEmpty ? decisionCtrl.text.trim() : null);
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
    final openCount = _list.where((c) => (c['status']?.toString() ?? 'open') == 'open').length;
    final reviewCount = _list.where((c) => (c['status']?.toString() ?? '') == 'under_review').length;
    final approvedCount = _list.where((c) => (c['status']?.toString() ?? '') == 'approved').length;
    final rejectedCount = _list.where((c) => (c['status']?.toString() ?? '') == 'rejected').length;
    final closedCount = _list.where((c) => (c['status']?.toString() ?? '') == 'closed').length;

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
                    Text('Claims Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Track and resolve customer claims', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Claim'),
              ),
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
                _TabChip('Open ($openCount)', 'open'),
                _TabChip('Under Review ($reviewCount)', 'under_review'),
                _TabChip('Approved ($approvedCount)', 'approved'),
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
                      ? const Center(child: Text('No claims yet', style: TextStyle(fontWeight: FontWeight.w600)))
                      : ListView.separated(
                          padding: EdgeInsets.all(isWide ? 24 : 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = filtered[i] as Map<String, dynamic>;
                            final status = c['status']?.toString() ?? 'open';
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['reason']?.toString() ?? 'Claim', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (c['description'] != null && c['description'].toString().isNotEmpty)
                                          Text(c['description'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        if (c['orderId'] != null)
                                          Text('Order: ${c['orderId']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(status: status, small: true),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _showStatusDialog(c),
                                    tooltip: 'Update Status',
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
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sel ? const Color(0xFF2563EB) : Colors.transparent, width: 2))),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF2563EB) : AppColors.textSecondary)),
        ),
      ),
    );
  }
}