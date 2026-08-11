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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/evidence/${widget.evidenceId}');
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      setState(() => _data = Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?.toString() ?? e.message ?? 'Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download URL')),
        );
      }
      return;
    }
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidence'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _data == null
                  ? const Center(child: Text('No data'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Status: ${_data!['status'] ?? '-'}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Frames: ${_data!['frameCount'] ?? 0}',
                            style: const TextStyle(color: AppColors.textSecondary)),
                        Text('Order: ${_data!['orderId'] ?? '-'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('Pack: ${_data!['packKey'] ?? '-'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 16),
                        if (_data!['thumbnailUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _data!['thumbnailUrl'].toString(),
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 80,
                                child: Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _open(_data!['packDownloadUrl']?.toString()),
                          icon: const Icon(Icons.download),
                          label: const Text('Download / open pack'),
                        ),
                        const SizedBox(height: 24),
                        const Text('Frames', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ..._frames(),
                      ],
                    ),
    );
  }

  List<Widget> _frames() {
    final frames = _data!['frames'];
    if (frames is! List || frames.isEmpty) {
      return [
        const Text(
          'No extracted frames yet. Pack/video download still works via button above.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ];
    }
    return frames.map<Widget>((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final url = m['downloadUrl']?.toString();
      return Card(
        child: ListTile(
          leading: url != null
              ? Image.network(url, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image))
              : const Icon(Icons.image_not_supported),
          title: Text(m['label']?.toString() ?? 'Frame ${m['sequence']}'),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _open(url),
          ),
        ),
      );
    }).toList();
  }
}