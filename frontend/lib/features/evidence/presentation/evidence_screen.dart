import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart'
    show EmptyHint, StatusBadge;
import 'evidence_detail_page.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});
  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  List<dynamic> _items = [];
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
      final b = res.data;
      final d = b is Map && b['data'] != null ? b['data'] : b;
      setState(() {
        _items = d is List ? d : [];
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to load evidence';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Map e) async {
    final id = '${e['id']}';
    if (id.isEmpty) return;
    try {
      final res = await ApiClient.instance.dio.get('/evidence/$id');
      final b = res.data;
      final detail = b is Map && b['data'] is Map
          ? Map<String, dynamic>.from(b['data'] as Map)
          : Map<String, dynamic>.from(e);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EvidenceDetailPage(evidenceId: id)),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EvidenceDetailPage(evidenceId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text('Evidence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_items.length} packs', style: const TextStyle(color: AppColors.textSecondary)),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
            ),
          ),
          if (_items.isEmpty)
            const SliverToBoxAdapter(child: EmptyHint('No evidence packs yet — finish a recording'))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final raw = _items[i];
                    final e = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                    final id = '${e['id'] ?? ''}';
                    final short = id.length > 8 ? id.substring(0, 8) : id;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openDetail(e),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                color: const Color(0xFF0F172A),
                                child: const Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 42),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(short, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      StatusBadge(status: e['status']?.toString() ?? '—', small: true),
                                      const Spacer(),
                                      Text('${e['frameCount'] ?? 0} f',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
