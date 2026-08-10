import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

class QueuedSegment {
  final String recordingId;
  final int sequence;
  final String filePath;
  final int durationSec;

  const QueuedSegment({
    required this.recordingId,
    required this.sequence,
    required this.filePath,
    required this.durationSec,
  });

  Future<List<int>> readBytes() => File(filePath).readAsBytes();
}

class RecordingUploadQueue {
  RecordingUploadQueue._();
  static final instance = RecordingUploadQueue._();

  Directory? _dir;

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final root = await getApplicationSupportDirectory();
    _dir = Directory('${root.path}${Platform.pathSeparator}ldp-recording-queue');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    return _dir!;
  }

  Future<File> _manifest() async => File('${(await _directory()).path}${Platform.pathSeparator}queue.json');

  Future<List<Map<String, dynamic>>> _readManifest() async {
    final file = await _manifest();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeManifest(List<Map<String, dynamic>> rows) async {
    final file = await _manifest();
    await file.writeAsString(jsonEncode(rows), flush: true);
  }

  Future<void> enqueue({required String recordingId, required int sequence, required XFile file, int durationSec = 45}) async {
    final dir = await _directory();
    final target = File('${dir.path}${Platform.pathSeparator}${recordingId}_$sequence.webm');
    await target.writeAsBytes(await file.readAsBytes(), flush: true);
    final rows = await _readManifest();
    rows.removeWhere((r) => r['recordingId'] == recordingId && r['sequence'] == sequence);
    rows.add({
      'recordingId': recordingId,
      'sequence': sequence,
      'filePath': target.path,
      'durationSec': durationSec,
    });
    await _writeManifest(rows);
  }

  Future<List<QueuedSegment>> pending() async {
    final rows = await _readManifest();
    final out = <QueuedSegment>[];
    for (final row in rows) {
      final path = row['filePath']?.toString();
      if (path == null || !await File(path).exists()) continue;
      out.add(QueuedSegment(
        recordingId: row['recordingId'].toString(),
        sequence: int.parse(row['sequence'].toString()),
        filePath: path,
        durationSec: int.tryParse(row['durationSec']?.toString() ?? '') ?? 45,
      ));
    }
    out.sort((a, b) => a.recordingId == b.recordingId ? a.sequence.compareTo(b.sequence) : a.recordingId.compareTo(b.recordingId));
    return out;
  }

  Future<void> remove(QueuedSegment segment) async {
    final rows = await _readManifest();
    rows.removeWhere((r) => r['recordingId'] == segment.recordingId && r['sequence'] == segment.sequence);
    await _writeManifest(rows);
    final file = File(segment.filePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> markFinalize({required String recordingId, required int durationSec}) async {
    final dir = await _directory();
    final file = File('${dir.path}${Platform.pathSeparator}${recordingId}_finalize.json');
    await file.writeAsString(jsonEncode({'recordingId': recordingId, 'durationSec': durationSec}), flush: true);
  }

  Future<List<Map<String, dynamic>>> pendingFinalizations() async {
    final dir = await _directory();
    if (!await dir.exists()) return [];
    final out = <Map<String, dynamic>>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('_finalize.json')) continue;
      try {
        final value = jsonDecode(await entity.readAsString());
        if (value is Map) out.add(Map<String, dynamic>.from(value));
      } catch (_) {}
    }
    return out;
  }

  Future<void> removeFinalize(String recordingId) async {
    final dir = await _directory();
    final file = File('${dir.path}${Platform.pathSeparator}${recordingId}_finalize.json');
    if (await file.exists()) await file.delete();
  }
}
