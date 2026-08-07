import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
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
  CameraController? _cam;
  bool _camReady = false;
  bool _recording = false;
  bool _busy = false;
  String? _recordingId;
  String? _error;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() => _error = 'Camera permission denied');
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'No camera found');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.medium, enableAudio: true);
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
    setState(() { _busy = true; _error = null; });
    try {
      // Prefer passed ids; else pick first order + warehouse from API
      String? orderId = widget.orderId;
      String? warehouseId = widget.warehouseId;

      if (orderId == null || warehouseId == null) {
        final ordersRes = await ApiClient.instance.dio.get('/orders');
        final oBody = ordersRes.data;
        final oList = oBody is Map && oBody['data'] is List ? oBody['data'] as List : <dynamic>[];
        if (oList.isNotEmpty) {
          orderId ??= (oList.first as Map)['id']?.toString();
        }
        final whRes = await ApiClient.instance.dio.get('/warehouses');
        final wBody = whRes.data;
        final wList = wBody is Map && wBody['data'] is List ? wBody['data'] as List : <dynamic>[];
        if (wList.isNotEmpty) {
          warehouseId ??= (wList.first as Map)['id']?.toString();
        }
      }

      if (orderId == null || warehouseId == null) {
        setState(() => _error = 'Need at least one order + warehouse');
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
          // Web may not support video file — still track API session
        }
      }

      setState(() {
        _recording = true;
        _recordingId = id;
        _startedAt = DateTime.now();
        _elapsed = Duration.zero;
      });
      _tick();
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

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      XFile? file;
      if (_cam != null && _cam!.value.isRecordingVideo) {
        try {
          file = await _cam!.stopVideoRecording();
        } catch (_) {}
      }

      final rid = _recordingId;
      if (rid != null) {
        await ApiClient.instance.dio.post('/recordings/$rid/stop', data: {
          'durationSec': _elapsed.inSeconds,
          'segmentCount': 1,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(file != null
                ? 'Recording saved · ${file.path.split(RegExp(r"[/\\]")).last}'
                : 'Session stopped · evidence created'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Stop failed');
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_recording ? 'Recording… ${_fmt(_elapsed)}' : 'Recording Session'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null && !_camReady
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                : !_camReady
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(_fmt(_elapsed),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 28,
                  color: Colors.white,
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: () async {
                    // simple: re-init opposite camera
                  },
                ),
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
                IconButton(
                  iconSize: 28,
                  color: Colors.white,
                  icon: const Icon(Icons.flash_on),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}