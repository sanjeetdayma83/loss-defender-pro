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
  List<dynamic> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/evidence');
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      setState(() => _list = data is List ? data : []);
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(dynamic item) {
    final id = item is Map ? item['id']?.toString() : null;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EvidenceDetailPage(evidenceId: id)),
    );
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Evidence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Packs from completed recordings — tap to preview / download',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _list.isEmpty
                      ? const Center(child: Text('No evidence yet', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 0, isWide ? 24 : 16, 24),
                          itemCount: _list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final e = _list[i] as Map;
                            final status = e['status']?.toString() ?? '-';
                            final frames = e['frameCount'] ?? 0;
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openDetail(e),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.photo_library, color: AppColors.accent, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (e['id']?.toString() ?? '').length > 8
                                                  ? '…${(e['id'].toString()).substring(e['id'].toString().length - 8)}'
                                                  : '${e['id']}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            Text('frames: $frames · order: ${e['orderId'] ?? '-'}',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text(status,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: status == 'ready' ? AppColors.success : AppColors.warning,
                                          )),
                                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}