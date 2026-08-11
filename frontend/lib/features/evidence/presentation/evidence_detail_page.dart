import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class EvidenceDetailPage extends StatefulWidget {
  final String evidenceId;
  const EvidenceDetailPage({super.key, required this.evidenceId});
  @override
  State<EvidenceDetailPage> createState() => _EvidenceDetailPageState();
}

class _EvidenceDetailPageState extends State<EvidenceDetailPage> {
  Map<String, dynamic>? _data;
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
      final res = await ApiClient.instance.dio.get('/evidence/${widget.evidenceId}');
      final body = res.data;
      final data = body is Map && body['data'] != null ? Map<String, dynamic>.from(body['data'] as Map) : Map<String, dynamic>.from(body as Map);
      setState(() { _data = data; _loading = false; });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message ?? 'Failed';
        _loading = false;
      });
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open URL')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evidence detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final frames = (d['frames'] is List) ? d['frames'] as List : [];
    final packUrl = d['packDownloadUrl']?.toString() ?? d['segmentDownloadUrl']?.toString();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Status: ${d['status']}', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('Frames: ${d['frameCount'] ?? frames.length}', style: const TextStyle(color: AppColors.textSecondary)),
        Text('packKey: ${d['packKey'] ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          FilledButton.icon(
            onPressed: packUrl == null ? null : () => _open(packUrl),
            icon: const Icon(Icons.download),
            label: const Text('Download pack / video'),
          ),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Frame gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (frames.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No extracted frames yet (placeholders / FFmpeg pending).\nUse Download for segment video.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemCount: frames.length,
            itemBuilder: (_, i) {
              final f = frames[i] is Map ? Map<String, dynamic>.from(frames[i] as Map) : <String, dynamic>{};
              final url = f['downloadUrl']?.toString();
              return InkWell(
                onTap: () => _open(url),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.image_outlined),
                      Text('F${f['index'] ?? f['sequence'] ?? i}', style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
