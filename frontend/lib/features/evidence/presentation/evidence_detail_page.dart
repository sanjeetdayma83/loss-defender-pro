import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class EvidenceDetailPage extends StatefulWidget {
  const EvidenceDetailPage({super.key, required this.evidenceId, this.initial});
  final String evidenceId;
  final Map<String, dynamic>? initial;

  @override
  State<EvidenceDetailPage> createState() => _EvidenceDetailPageState();
}

class _EvidenceDetailPageState extends State<EvidenceDetailPage> {
  Map<String, dynamic>? _row;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _row = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/evidence/${widget.evidenceId}');
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      if (data is Map) _row = Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      _error = e.response?.data?['message']?.toString() ?? e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = _row?['frames'];
    final frameList = frames is List ? frames : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Evidence detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                Text('Status: ${_row?['status'] ?? '—'}'),
                Text('Frame count: ${_row?['frameCount'] ?? frameList.length}'),
                Text('Pack key: ${_row?['packKey'] ?? '—'}'),
                const SizedBox(height: 16),
                const Text('Frames', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (frameList.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.image_not_supported),
                      title: Text('No frame keys yet'),
                      subtitle: Text('Run backend extract-frames when FFmpeg path is fixed'),
                    ),
                  )
                else
                  ...frameList.map((f) => ListTile(
                        leading: const Icon(Icons.image),
                        title: Text(f.toString()),
                      )),
              ],
            ),
    );
  }
}
