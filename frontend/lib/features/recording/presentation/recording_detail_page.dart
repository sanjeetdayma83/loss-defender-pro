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
  Map<String, dynamic>? _rec;
  List<dynamic> _segments = [];
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
      final r = await ApiClient.instance.dio.get('/recordings/${widget.recordingId}');
      final body = r.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      _rec = Map<String, dynamic>.from(data as Map);

      final d = await ApiClient.instance.dio.get('/recordings/${widget.recordingId}/download');
      final db = d.data;
      final dd = db is Map && db['data'] != null ? db['data'] : db;
      final segs = dd is Map ? dd['segments'] : null;
      _segments = segs is List ? segs : [];
    } on DioException catch (e) {
      _error = e.message ?? 'Failed';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Status: ${_rec?['status'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Segments: ${_rec?['segmentCount'] ?? _segments.length}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    const Text('Video segments', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_segments.isEmpty)
                      const Text('No uploaded segments', style: TextStyle(color: AppColors.textSecondary)),
                    ..._segments.map((s) {
                      final m = Map<String, dynamic>.from(s as Map);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: Text('Segment ${m['sequence']}'),
                          subtitle: Text('${m['b2Key'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => _open(m['downloadUrl']?.toString()),
                          ),
                          onTap: () => _open(m['downloadUrl']?.toString()),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}