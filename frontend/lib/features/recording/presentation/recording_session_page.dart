import 'dart:async';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RecordingSessionPage extends StatefulWidget {
  final String? orderId;
  final String? warehouseId;
  const RecordingSessionPage({super.key, this.orderId, this.warehouseId});

  @override
  State<RecordingSessionPage> createState() => _RecordingSessionPageState();
}

class _RecordingSessionPageState extends State<RecordingSessionPage> {
  int _segmentIndex = 0;
  Timer? _segmentTimer;
  CameraController? _cam;
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  bool _camReady = false;
  bool _recording = false;
  bool _paused = false;
  bool _busy = false;
  bool _torch = false;
  String? _recordingId;
  String? _error;
  String? _status;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  Duration _pausedAccum = Duration.zero;
  DateTime? _pauseStarted;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _initCamera({int? index}) async {
    setState(() {
      _camReady = false;
      _error = null;
    });
    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          setState(() => _error = 'Camera permission denied — open app settings');
          return;
        }
        await Permission.microphone.request();
      }
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _error = kIsWeb
            ? 'No camera (web needs HTTPS + permission)'
            : 'No camera found');
        return;
      }
      _camIndex = index ?? _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_camIndex < 0) _camIndex = 0;
      await _cam?.dispose();
      final ctrl = CameraController(
        _cams[_camIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cam = ctrl;
        _camReady = true;
        _torch = false;
      });
    } catch (e) {
      setState(() => _error = 'Camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cams.length < 2 || _recording) return;
    final next = (_camIndex + 1) % _cams.length;
    await _initCamera(index: next);
  }

  Future<void> _toggleTorch() async {
    if (_cam == null || !_cam!.value.isInitialized) return;
    try {
      _torch = !_torch;
      await _cam!.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      setState(() => _status = 'Torch: $e');
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stop recording?'),
          content: const Text('This will finalize the session and upload the last segment.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
          ],
        ),
      );
      if (ok == true) await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _pauseResume() async {
    if (!_recording || _cam == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_paused) {
        // resume
        if (_pauseStarted != null) {
          _pausedAccum += DateTime.now().difference(_pauseStarted!);
        }
        if (!kIsWeb) {
          try {
            await _cam!.resumeVideoRecording();
          } catch (e) {
            setState(() => _status = 'Resume: $e');
          }
        }
        _pauseStarted = null;
        setState(() => _paused = false);
        _tick();
      } else {
        if (!kIsWeb) {
          try {
            await _cam!.pauseVideoRecording();
          } catch (e) {
            setState(() => _status = 'Pause unsupported: $e');
            return;
          }
        }
        _pauseStarted = DateTime.now();
        setState(() => _paused = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
        setState(() => _error = 'Order + warehouse required (use Start picker)');
        return;
      }

      final res = await ApiClient.instance.dio.post('/recordings/start', data: {
        'orderId': orderId,
        'warehouseId': warehouseId,
      });
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final id = data is Map ? data['id']?.toString() : null;

      if (_cam != null && _cam!.value.isInitialized) {
        try {
          await _cam!.startVideoRecording();
        } catch (e) {
          if (kIsWeb) {
            setState(() => _status =
                'Web: file recording limited — session tracked, upload may skip');
          } else {
            setState(() => _error = 'startVideoRecording: $e');
            return;
          }
        }
      }

      setState(() {
        _recording = true;
        _paused = false;
        _recordingId = id;
        _startedAt = DateTime.now();
        _elapsed = Duration.zero;
        _pausedAccum = Duration.zero;
        _segmentIndex = 0;
      });
      _tick();
      _segmentTimer?.cancel();
      if (!kIsWeb) {
        _segmentTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
          if (!_recording || _paused || _cam == null || !_cam!.value.isRecordingVideo) return;
          final rid = _recordingId;
          if (rid == null) return;
          try {
            final f = await _cam!.stopVideoRecording();
            await _uploadSegment(rid, f, _segmentIndex);
            _segmentIndex++;
            await _cam!.startVideoRecording();
            if (mounted) setState(() => _status = 'Rolling segment #$_segmentIndex');
          } catch (e) {
            if (mounted) setState(() => _status = 'Segment roll: $e');
          }
        });
      }
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Start failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tick() {
    if (!_recording || _startedAt == null || _paused) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_recording || _paused) return;
      final raw = DateTime.now().difference(_startedAt!);
      setState(() => _elapsed = raw - _pausedAccum);
      _tick();
    });
  }

  Future<int> _uploadSegment(String rid, XFile? file, int sequence) async {
    if (file == null) return 0;
    setState(() => _status = 'Getting upload URL…');
    final presignRes = await ApiClient.instance.dio.post(
      '/recordings/$rid/segments/presign',
      data: {'segmentIndex': sequence, 'contentType': 'video/webm'},
    );
    final pBody = presignRes.data;
    final p = pBody is Map && pBody['data'] != null ? pBody['data'] : pBody;
    if (p is! Map) return 0;
    final configured = p['configured'] == true;
    final uploadUrl = p['uploadUrl']?.toString();
    final key = p['key']?.toString();
    if (!configured || uploadUrl == null || key == null) {
      setState(() => _status = 'B2 not configured — segment skipped');
      return 0;
    }
    setState(() => _status = 'Uploading segment…');
    final bytes = await file.readAsBytes();
    final size = bytes.length;
    final put = Dio();
    await put.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Type': 'video/webm', 'Content-Length': size},
        contentType: 'video/webm',
      ),
    );
    setState(() => _status = 'Registering segment…');
    await ApiClient.instance.dio.post('/recordings/$rid/segments', data: {
      'sequence': sequence,
      'b2Key': key,
      'sizeBytes': size,
      'durationSec': _elapsed.inSeconds,
    });
    return size;
  }

  Future<void> _stop() async {
    _segmentTimer?.cancel();
    _segmentTimer = null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      XFile? file;
      if (_cam != null && _cam!.value.isRecordingVideo) {
        try {
          file = await _cam!.stopVideoRecording();
        } catch (_) {}
      }
      final rid = _recordingId;
      var uploadedBytes = 0;
      if (rid != null && file != null) {
        try {
          uploadedBytes = await _uploadSegment(rid, file, _segmentIndex);
        } catch (e) {
          setState(() => _status = 'Upload failed: $e');
        }
      }
      if (rid != null) {
        setState(() => _status = 'Finalizing…');
        await ApiClient.instance.dio.post('/recordings/$rid/stop', data: {
          'durationSec': _elapsed.inSeconds,
          'segmentCount': uploadedBytes > 0 ? 1 : 0,
        });
      }
      if (!mounted) return;
      setState(() {
        _recording = false;
        _paused = false;
        _status = uploadedBytes > 0
            ? 'Saved + uploaded (${(uploadedBytes / 1024).toStringAsFixed(1)} KB)'
            : 'Session stopped (upload skipped)';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploadedBytes > 0
            ? 'Recording uploaded'
            : 'Stopped (check B2 / camera file)'),
      ));
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Stop failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Recording Session'),
        actions: [
          if (_cams.length > 1 && !_recording)
            IconButton(icon: const Icon(Icons.cameraswitch), onPressed: _switchCamera),
          IconButton(
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            onPressed: _camReady ? _toggleTorch : null,
          ),
          if (_error != null && _error!.contains('permission'))
            IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_camReady
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Starting camera…',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                        if (_error != null && _error!.contains('permission')) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _openSettings, child: const Text('Open settings')),
                        ],
                      ],
                    ),
                  )
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
                            decoration: BoxDecoration(
                              color: _paused ? Colors.orange.shade800 : Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(_paused ? Icons.pause : Icons.fiber_manual_record,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(_fmt(_elapsed),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      if (_status != null)
                        Positioned(
                          bottom: 48,
                          left: 16,
                          right: 16,
                          child: Text(_status!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.lightGreenAccent)),
                        ),
                      if (_error != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.orangeAccent)),
                        ),
                    ],
                  ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_recording)
                  IconButton(
                    iconSize: 36,
                    color: Colors.white,
                    onPressed: _busy ? null : _pauseResume,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause_circle_outline),
                  ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: _busy ? null : _toggle,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _recording ? AppColors.danger : Colors.white24,
                    ),
                    child: Icon(
                      _recording ? Icons.stop : Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
