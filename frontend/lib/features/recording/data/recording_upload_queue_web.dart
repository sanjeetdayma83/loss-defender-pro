import 'package:camera/camera.dart';

class QueuedSegment {
  final String recordingId;
  final int sequence;
  final XFile file;
  final int durationSec;

  const QueuedSegment({
    required this.recordingId,
    required this.sequence,
    required this.file,
    required this.durationSec,
  });

  Future<List<int>> readBytes() => file.readAsBytes();
}

class RecordingUploadQueue {
  RecordingUploadQueue._();
  static final instance = RecordingUploadQueue._();
  final List<QueuedSegment> _pending = [];
  final List<Map<String, dynamic>> _finalize = [];

  Future<void> enqueue({required String recordingId, required int sequence, required XFile file, int durationSec = 45}) async {
    _pending.removeWhere((x) => x.recordingId == recordingId && x.sequence == sequence);
    _pending.add(QueuedSegment(recordingId: recordingId, sequence: sequence, file: file, durationSec: durationSec));
  }

  Future<List<QueuedSegment>> pending() async => List<QueuedSegment>.from(_pending);

  Future<void> remove(QueuedSegment segment) async {
    _pending.removeWhere((x) => x.recordingId == segment.recordingId && x.sequence == segment.sequence);
  }

  Future<void> markFinalize({required String recordingId, required int durationSec}) async {
    _finalize.removeWhere((x) => x['recordingId'] == recordingId);
    _finalize.add({'recordingId': recordingId, 'durationSec': durationSec});
  }

  Future<List<Map<String, dynamic>>> pendingFinalizations() async => List<Map<String, dynamic>>.from(_finalize);

  Future<void> removeFinalize(String recordingId) async {
    _finalize.removeWhere((x) => x['recordingId'] == recordingId);
  }
}
