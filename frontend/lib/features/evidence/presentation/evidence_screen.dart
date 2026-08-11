import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'evidence_detail_page.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});
  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  List<Map<String, dynamic>> _items = [];
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
      final res = await ApiClient.instance.dio.get('/evidence');
      final d = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      setState(() {
        _items = (d is List ? d : [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  void _open(String id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EvidenceDetailPage(evidenceId: id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Evidence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Total ${_items.length}', style: const TextStyle(color: AppColors.textSecondary)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('No evidence yet — complete a recording'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      final id = e['id']?.toString() ?? '';
                      final status = e['status']?.toString() ?? '—';
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: id.isEmpty ? null : () => _open(id),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 72,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.videocam_outlined, size: 36),
                                ),
                                const SizedBox(height: 8),
                                Text(id.length > 12 ? '${id.substring(0, 8)}…' : id,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('Status: $status · frames ${e['frameCount'] ?? 0}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const Spacer(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(onPressed: () => _open(id), child: const Text('Open')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

