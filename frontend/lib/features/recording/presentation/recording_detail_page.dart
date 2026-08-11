import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RecordingDetailPage extends StatefulWidget {
  final String recordingId;
  const RecordingDetailPage({super.key, required this.recordingId});
  @override
  State<RecordingDetailPage> createState() => _RecordingDetailPageState();
}

class _RecordingDetailPageState extends State<RecordingDetailPage> {
  Map<String, dynamic>? _meta;
  List<dynamic> _segments = [];
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
      try {
        final one = await ApiClient.instance.dio.get('/recordings/${widget.recordingId}');
        final b = one.data;
        _meta = b is Map && b['data'] != null ? Map<String, dynamic>.from(b['data'] as Map) : null;
      } catch (_) {}
      final dl = await ApiClient.instance.dio.get('/recordings/${widget.recordingId}/download');
      final body = dl.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final segs = data is Map ? (data['segments'] as List? ?? []) : [];
      setState(() { _segments = segs; _loading = false; });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recording review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_meta != null) ...[
                      Text('Status: ${_meta!['status']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Duration: ${_meta!['durationSec'] ?? '—'}s · segments: ${_meta!['segmentCount'] ?? _segments.length}',
                          style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                    ],
                    const Text('Segments / playback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_segments.isEmpty)
                      const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No segments uploaded yet')))
                    else
                      ..._segments.asMap().entries.map((e) {
                        final s = e.value is Map ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
                        final url = s['downloadUrl']?.toString();
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.play_circle_outline),
                            title: Text('Segment ${s['sequence'] ?? e.key}'),
                            subtitle: Text(s['b2Key']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: url == null ? null : () => _open(url),
                            ),
                            onTap: url == null ? null : () => _open(url),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
