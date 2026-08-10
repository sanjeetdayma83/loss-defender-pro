import 'dart:async';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/recording_upload_queue.dart';

class RecordingSessionPage extends StatefulWidget {
  final String? orderId;
  final String? warehouseId;
  const RecordingSessionPage({super.key, this.orderId, this.warehouseId});
  @override
  State<RecordingSessionPage> createState() => _RecordingSessionPageState();
}

class _RecordingSessionPageState extends State<RecordingSessionPage> {
  static const segmentDuration = Duration(seconds: 45);
  CameraController? _cam;
  Timer? _segmentTimer;
  bool _camReady = false, _recording = false, _busy = false, _rolling = false;
  String? _recordingId, _error, _status;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  int _nextSequence = 0;
  Future<void>? _drainFuture;

  @override
  void initState() {
    super.initState();
    _initCamera();
    unawaited(_drainQueue());
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      if (!kIsWeb) {
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          if (mounted) setState(() => _error = 'Camera permission denied');
          return;
        }
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: true);
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cam = controller;
        _camReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera: $e');
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      String? orderId = widget.orderId;
      String? warehouseId = widget.warehouseId;
      if (orderId == null || warehouseId == null) {
        final orders = await ApiClient.instance.dio.get('/orders');
        final body = orders.data;
        final list = body is Map && body['data'] is List ? body['data'] as List : (body is List ? body : <dynamic>[]);
        if (list.isNotEmpty) orderId ??= (list.first as Map)['id']?.toString();
        final warehouses = await ApiClient.instance.dio.get('/warehouses');
        final warehouseBody = warehouses.data;
        final warehouseList = warehouseBody is Map && warehouseBody['data'] is List ? warehouseBody['data'] as List : (warehouseBody is List ? warehouseBody : <dynamic>[]);
        if (warehouseList.isNotEmpty) warehouseId ??= (warehouseList.first as Map)['id']?.toString();
      }
      if (orderId == null || warehouseId == null) throw Exception('Need orderId + warehouseId');
      final response = await ApiClient.instance.dio.post('/recordings/start', data: {'orderId': orderId, 'warehouseId': warehouseId});
      final body = response.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final id = data is Map ? data['id']?.toString() : null;
      if (id == null) throw Exception('Recording id missing');
      _recordingId = id;
      _startedAt = DateTime.now();
      _nextSequence = 0;
      await _startCameraSegment();
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _scheduleRollover();
      _tick();
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Start failed');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startCameraSegment() async {
    if (_cam == null || !_cam!.value.isInitialized) throw Exception('Camera not ready');
    if (!_cam!.value.isRecordingVideo) await _cam!.startVideoRecording();
  }

  void _scheduleRollover() {
    _segmentTimer?.cancel();
    _segmentTimer = Timer(segmentDuration, _rollover);
  }

  Future<void> _rollover() async {
    if (!_recording || _rolling) return;
    _rolling = true;
    try {
      final sequence = _nextSequence++;
      XFile? file;
      if (_cam!.value.isRecordingVideo) file = await _cam!.stopVideoRecording();
      await _startCameraSegment();
      _scheduleRollover();
      if (file != null && _recordingId != null) {
        unawaited(_queueAndUpload(_recordingId!, file, sequence));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Segment rollover failed: $e');
      if (_recording) _scheduleRollover();
    } finally {
      _rolling = false;
    }
  }

  void _tick() {
    if (!_recording || _startedAt == null) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_recording) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      _tick();
    });
  }

  Future<void> _queueAndUpload(String recordingId, XFile file, int sequence) async {
    await RecordingUploadQueue.instance.enqueue(
      recordingId: recordingId,
      sequence: sequence,
      file: file,
      durationSec: 45,
    );
    await _drainQueue();
  }

  Future<void> _drainQueue() {
    final current = _drainFuture;
    if (current != null) return current;
    final future = _drainQueueInternal();
    _drainFuture = future;
    return future.whenComplete(() => _drainFuture = null);
  }

  Future<void> _drainQueueInternal() async {
    final queue = RecordingUploadQueue.instance;
    final segments = await queue.pending();
    for (final segment in segments) {
      try {
        if (mounted) setState(() => _status = 'Uploading segment ${segment.sequence + 1}…');
        final bytes = await segment.readBytes();
        final presign = await ApiClient.instance.dio.post(
          '/recordings/${segment.recordingId}/segments/presign',
          data: {'segmentIndex': segment.sequence, 'contentType': 'video/webm'},
        );
        final raw = presign.data;
        final data = raw is Map && raw['data'] != null ? raw['data'] : raw;
        if (data is! Map || data['configured'] != true || data['uploadUrl'] == null || data['key'] == null) {
          throw Exception('B2 upload is not configured');
        }
        final put = Dio();
        await put.put(
          data['uploadUrl'],
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {'Content-Type': 'video/webm', 'Content-Length': bytes.length},
            contentType: 'video/webm',
          ),
        );
        await ApiClient.instance.dio.post(
          '/recordings/${segment.recordingId}/segments',
          data: {
            'sequence': segment.sequence,
            'b2Key': data['key'],
            'sizeBytes': bytes.length,
            'durationSec': segment.durationSec,
          },
        );
        await queue.remove(segment);
      } catch (e) {
        if (mounted) setState(() => _status = 'Offline/upload pending — will retry automatically');
        break;
      }
    }

    final finalizations = await queue.pendingFinalizations();
    for (finalization in finalizations) {
      final recordingId = finalization['recordingId']?.toString();
      final durationSec = int.tryParse(finalization['durationSec']?.toString() ?? '') ?? 0;
      if (recordingId == null) continue;
      final remaining = (await queue.pending()).where((s) => s.recordingId == recordingId).isNotEmpty;
      if (remaining) continue;
      try {
        await ApiClient.instance.dio.post('/recordings/$recordingId/stop', data: {'durationSec': durationSec});
        await queue.removeFinalize(recordingId);
        if (_recordingId == recordingId && mounted) {
          setState(() => _status = 'Uploaded — evidence processing started');
        }
      } catch (_) {
        if (mounted) setState(() => _status = 'Evidence finalization pending — will retry automatically');
      }
    }
  }

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    _segmentTimer?.cancel();
    try {
      final recordingId = _recordingId;
      if (recordingId == null) throw Exception('Recording id missing');
      XFile? file;
      if (_cam != null && _cam!.value.isRecordingVideo) file = await _cam!.stopVideoRecording();
      if (file != null) {
        final sequence = _nextSequence++;
        await RecordingUploadQueue.instance.enqueue(recordingId: recordingId, sequence: sequence, file: file, durationSec: 45);
      }
      await RecordingUploadQueue.instance.markFinalize(recordingId: recordingId, durationSec: _elapsed.inSeconds);
      await _drainQueue();
      final stillPending = (await RecordingUploadQueue.instance.pending()).any((s) => s.recordingId == recordingId);
      final finalizationPending = (await RecordingUploadQueue.instance.pendingFinalizations()).any((x) => x['recordingId'] == recordingId);
      if (stillPending || finalizationPending) {
        if (mounted) {
          setState(() {
            _status = 'Saved locally. Upload will resume automatically when connection returns.';
            _recording = false;
          });
        }
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording uploaded. Evidence processing started.')));
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Stop failed');
    } catch (e) {
      if (mounted) setState(() => _error = 'Stop failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _recording = false;
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Recording Session')),
    body: Column(
      children: [
        Expanded(
          child: !_camReady
              ? Center(child: Text(_error ?? 'Starting camera…', style: const TextStyle(color: Colors.white70)))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cam!),
                    if (_recording)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(_fmt(_elapsed), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    if (_status != null)
                      Positioned(bottom: 48, left: 16, right: 16, child: Text(_status!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.lightGreenAccent))),
                    if (_error != null)
                      Positioned(bottom: 16, left: 16, right: 16, child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent))),
                  ],
                ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _busy ? null : _toggle,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: _recording ? AppColors.danger : Colors.white24),
                  child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 36),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
