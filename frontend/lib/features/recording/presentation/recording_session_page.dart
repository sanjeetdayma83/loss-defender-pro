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
  bool _camReady = false;
  bool _recording = false;
  bool _busy = false;
  String? _recordingId;
  String? _error;
  String? _status;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

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

  Future<void> _initCamera() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          setState(() => _error = 'Camera permission denied');
          return;
        }
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'No camera found (web may need HTTPS/permission)');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cam = ctrl;
        _camReady = true;
      });
    } catch (e) {
      setState(() => _error = 'Camera: $e');
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
        final ordersRes = await ApiClient.instance.dio.get('/orders');
        final oBody = ordersRes.data;
        final oList = oBody is Map && oBody['data'] is List
            ? oBody['data'] as List
            : (oBody is List ? oBody : <dynamic>[]);
        if (oList.isNotEmpty) {
          orderId ??= (oList.first as Map)['id']?.toString();
        }
        final whRes = await ApiClient.instance.dio.get('/warehouses');
        final wBody = whRes.data;
        final wList = wBody is Map && wBody['data'] is List
            ? wBody['data'] as List
            : (wBody is List ? wBody : <dynamic>[]);
        if (wList.isNotEmpty) {
          warehouseId ??= (wList.first as Map)['id']?.toString();
        }
      }

      if (orderId == null || warehouseId == null) {
        setState(() => _error = 'Need orderId + warehouseId');
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
        } catch (_) {
          // Web may not support file recording — session still tracked
        }
      }

      setState(() {
        _recording = true;
        _recordingId = id;
        _startedAt = DateTime.now();
        _elapsed = Duration.zero;
      });
      _tick();
      _segmentIndex = 0;
      _segmentTimer?.cancel();
      _segmentTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
        if (!_recording || _cam == null || !_cam!.value.isRecordingVideo) return;
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
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Start failed');
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<int> _uploadSegment(String rid, XFile? file, int sequence) async {
    if (file == null) return 0;

    setState(() => _status = 'Getting upload URL…');
    final presignRes = await ApiClient.instance.dio.post(
      '/recordings/$rid/segments/presign',
      data: {
        'segmentIndex': sequence,
        'contentType': 'video/webm',
      },
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

    // Direct PUT to B2/S3 presigned URL (no auth header)
    final put = Dio();
    await put.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': 'video/webm',
          'Content-Length': size,
        },
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
          setState(() => _status = 'Upload failed: $e (still stopping session)');
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
        _status = uploadedBytes > 0
            ? 'Saved + uploaded (${(uploadedBytes / 1024).toStringAsFixed(1)} KB)'
            : 'Session stopped (no file upload)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadedBytes > 0
              ? 'Recording uploaded & evidence linked'
              : 'Recording stopped (upload skipped — check B2 / camera file)'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
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
      ),
      body: Column(
        children: [
          Expanded(
            child: !_camReady
                ? Center(
                    child: Text(
                      _error ?? 'Starting camera…',
                      style: const TextStyle(color: Colors.white70),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(_fmt(_elapsed),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
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