import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _orderCtrl = TextEditingController();
  final _manualCtrl = TextEditingController();
  bool _cameraOn = false;
  bool _busy = false;
  String? _lastResult;
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void dispose() {
    _orderCtrl.dispose();
    _manualCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String barcode) async {
    final orderId = _orderCtrl.text.trim();
    if (orderId.isEmpty) {
      await AppDialogs.info(context,
          title: 'Order required',
          message: 'Enter Order UUID before scanning.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await ApiClient.instance.dio.post('/scanner/scan', data: {
        'orderId': orderId,
        'barcode': barcode,
      });
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final result = data is Map ? data['result']?.toString() : null;
      setState(() => _lastResult = 'OK: $barcode → $result');
      if (result == 'matched') {
        await AppDialogs.success(context, message: 'Matched: $barcode');
      } else {
        await AppDialogs.info(context,
            title: 'Scan result', message: '$result — $barcode');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ??
              e.response!.data['error']?['message'] ??
              e.message)
          : e.message;
      final code = e.response?.statusCode;
      if (code == 409) {
        await AppDialogs.duplicateScan(context, message: msg?.toString() ?? 'Duplicate');
      } else {
        await AppDialogs.error(context, message: msg?.toString() ?? 'Scan failed');
      }
      setState(() => _lastResult = 'ERR: $msg');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Padding(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Scanner',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Scan barcodes against an order — duplicate & SKU checks live.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _orderCtrl,
            decoration: const InputDecoration(
              labelText: 'Order ID (UUID)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Manual barcode',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _submit(v.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        final v = _manualCtrl.text.trim();
                        if (v.isNotEmpty) _submit(v);
                      },
                child: const Text('Submit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => setState(() => _cameraOn = !_cameraOn),
                icon: Icon(_cameraOn ? Icons.videocam_off : Icons.qr_code_scanner),
                label: Text(_cameraOn ? 'Stop Camera' : 'Start Camera'),
              ),
              const SizedBox(width: 12),
              if (_lastResult != null)
                Expanded(
                  child: Text(_lastResult!,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cameraOn)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final bars = capture.barcodes;
                    if (bars.isEmpty) return;
                    final raw = bars.first.rawValue;
                    if (raw != null && raw.isNotEmpty) {
                      _submit(raw);
                    }
                  },
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('Camera off — use manual entry or start camera',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}