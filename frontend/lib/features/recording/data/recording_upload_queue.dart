import 'package:camera/camera.dart';

import 'recording_upload_queue_web.dart'
    if (dart.library.io) 'recording_upload_queue_io.dart' as platform;

export 'recording_upload_queue_web.dart'
    if (dart.library.io) 'recording_upload_queue_io.dart';

class RecordingUploadQueueFacade {
  RecordingUploadQueueFacade._();
  static final instance = RecordingUploadQueueFacade._();
  final _delegate = platform.RecordingUploadQueue.instance;

  Future<void> enqueue({required String recordingId, required int sequence, required XFile file, int durationSec = 45}) =>
      _delegate.enqueue(recordingId: recordingId, sequence: sequence, file: file, durationSec: durationSec);
}
