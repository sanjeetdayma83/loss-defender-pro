import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class RecordingDetailPage extends StatefulWidget {
  const RecordingDetailPage({super.key, required this.recordingId, this.initial});
  final String recordingId;
  final Map<String, dynamic>? initial;

  @override
  State<RecordingDetailPage> createState() => _RecordingDetailPageState();
}

class _RecordingDetailPageState extends State<RecordingDetailPage> {
  Map<String, dynamic>? _rec;
  VideoPlayerController? _player;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rec = widget.initial;
    _load();
  }

  Future<String?> _resolveUrl(Map<String, dynamic>? rec) async {
    if (rec == null) return null;
    var url = rec['playbackUrl']?.toString() ??
        rec['videoUrl']?.toString() ??
        rec['segmentUrl']?.toString();
    if (url != null && url.startsWith('http')) return url;

    final key = rec['storageKey']?.toString() ??
        rec['segmentKey']?.toString() ??
        rec['packKey']?.toString() ??
        rec['key']?.toString();
    if (key == null || key.isEmpty) return null;

    try {
      final pr = await ApiClient.instance.dio.post(
        '/storage/presign-download',
        data: {'key': key},
      );
      final d = pr.data is Map && pr.data['data'] != null ? pr.data['data'] : pr.data;
      if (d is Map) return d['downloadUrl']?.toString();
    } catch (_) {}
    return null;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/recordings/${widget.recordingId}');
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      _rec = data is Map ? Map<String, dynamic>.from(data) : _rec;
      final url = await _resolveUrl(_rec);
      if (url != null && url.startsWith('http')) {
        await _player?.dispose();
        _player = VideoPlayerController.networkUrl(Uri.parse(url));
        await _player!.initialize();
      }
    } on DioException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recording detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                Text('Status: ${_rec?['status'] ?? '—'}'),
                Text('Segments: ${_rec?['segmentCount'] ?? '—'}'),
                const SizedBox(height: 16),
                if (_player != null && _player!.value.isInitialized) ...[
                  AspectRatio(
                    aspectRatio: _player!.value.aspectRatio == 0 ? 16 / 9 : _player!.value.aspectRatio,
                    child: VideoPlayer(_player!),
                  ),
                  VideoProgressIndicator(_player!, allowScrubbing: true),
                  IconButton(
                    icon: Icon(_player!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () => setState(() {
                      _player!.value.isPlaying ? _player!.pause() : _player!.play();
                    }),
                  ),
                ] else
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.videocam_off),
                      title: Text('No stream URL yet'),
                      subtitle: Text('Upload a segment or set storageKey on recording'),
                    ),
                  ),
              ],
            ),
    );
  }
}
