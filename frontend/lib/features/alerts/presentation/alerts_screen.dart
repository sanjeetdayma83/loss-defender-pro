import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _list = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/alerts');
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      setState(() => _list = data is List ? data : []);
    } catch (_) {
      setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'all') return _list;
    return _list.where((a) {
      final severity = (a is Map ? a['severity']?.toString() : '') ?? 'info';
      return severity == _filter;
    }).toList();
  }

  int get _openCount => _list.where((a) => (a['resolved'] != true)).length;
  int get _criticalCount => _list.where((a) => (a['severity']?.toString() ?? '') == 'critical').length;
  int get _highCount => _list.where((a) => (a['severity']?.toString() ?? '') == 'high').length;

  Future<void> _resolve(Map<String, dynamic> alert) async {
    final confirm = await AppDialogs.confirm(context, title: 'Resolve Alert?', message: 'Mark this alert as resolved?');
    if (confirm != true) return;
    try {
      await ApiClient.instance.dio.post('/audit-logs', data: {
        'action': 'alert.resolve',
        'entity': 'Alert',
        'entityId': alert['id']?.toString(),
        'after': {'resolved': true, 'resolvedAt': DateTime.now().toIso8601String()},
      });
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert resolved')));
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed')));
    }
  }

  Future<void> _assign(Map<String, dynamic> alert) async {
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Assign Alert'),
      content: TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'User Email')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign'))],
    ));
    if (ok != true || emailCtrl.text.trim().isEmpty) return;
    try {
      await ApiClient.instance.dio.post('/audit-logs', data: {
        'action': 'alert.assign',
        'entity': 'Alert',
        'entityId': alert['id']?.toString(),
        'after': {'assignedTo': emailCtrl.text.trim(), 'assignedAt': DateTime.now().toIso8601String()},
      });
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert assigned')));
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed')));
    }
  }

  Color _severityColor(String? s) {
    switch (s) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              _Badge(count: _openCount, label: 'Open', color: AppColors.warning),
              const SizedBox(width: 8),
              _Badge(count: _criticalCount, label: 'Critical', color: Colors.red),
              const SizedBox(width: 8),
              _Badge(count: _highCount, label: 'High', color: Colors.orange),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
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
                _FilterChip(label: 'All', key: 'all'),
                _FilterChip(label: 'Critical', key: 'critical'),
                _FilterChip(label: 'High', key: 'high'),
                _FilterChip(label: 'Medium', key: 'medium'),
                _FilterChip(label: 'Info', key: 'info'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(child: Text('No alerts', style: TextStyle(fontWeight: FontWeight.w600)))
                  : ListView.separated(
                      padding: EdgeInsets.all(isWide ? 24 : 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = _filtered[i] as Map<String, dynamic>;
                        final severity = a['severity']?.toString() ?? 'info';
                        final resolved = a['resolved'] == true;
                        final assignedTo = a['assignedTo']?.toString();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: resolved ? AppColors.success.withOpacity(0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: resolved ? AppColors.success.withOpacity(0.3) : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.notifications_outlined, color: _severityColor(severity), size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(a['message']?.toString() ?? a['type']?.toString() ?? 'Alert', style: const TextStyle(fontSize: 13)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: _severityColor(severity).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                    child: Text(severity.toUpperCase(), style: TextStyle(color: _severityColor(severity), fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Created: ${a['createdAt']?.toString() ?? '—'}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  if (assignedTo != null) ...[
                                    const SizedBox(width: 16),
                                    Text('Assigned: $assignedTo', style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                                  ],
                                  if (resolved) ...[
                                    const SizedBox(width: 16),
                                    const Text('Resolved', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!resolved) ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _assign(a),
                                      icon: const Icon(Icons.person_add, size: 16),
                                      label: const Text('Assign'),
                                      style: OutlinedButton.styleFrom(minimumSize: const Size(100, 36)),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () => _resolve(a),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Resolve'),
                                      style: FilledButton.styleFrom(minimumSize: const Size(100, 36)),
                                    ),
                                  ] else
                                    TextButton.icon(
                                      onPressed: () => _resolve(a), // re-open
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Re-open'),
                                    ),
                                ],
                              ),
                            ],
                          );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _FilterChip({required String label, required String key}) {
    final sel = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filter = key),
        selectedColor: const Color(0xFF2563EB).withOpacity(0.12),
        checkmarkColor: const Color(0xFF2563EB),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _Badge({required this.count, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      ]),
    );
  }
}