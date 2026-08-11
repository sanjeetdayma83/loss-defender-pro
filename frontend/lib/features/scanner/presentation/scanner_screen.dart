import '../../../core/widgets/ui_kit.dart';
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
  final _manualCtrl = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  String? _orderId;
  bool _loadingOrders = true;
  bool _cameraOn = false;
  bool _busy = false;
  String? _lastResult;

  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final res = await ApiClient.instance.dio.get('/orders');
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      final list = (data is List ? data : <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((o) {
            final s = (o['status'] ?? '').toString();
            return ['packing', 'queued', 'synced', 'recording', 'scanned'].contains(s);
          })
          .toList();
      // fallback: show all if none scannable
      final all = (data is List ? data : <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _orders = list.isNotEmpty ? list : all;
        if (_orders.isNotEmpty && _orderId == null) {
          _orderId = _orders.first['id']?.toString();
        }
        _loadingOrders = false;
      });
    } on DioException catch (e) {
      setState(() => _loadingOrders = false);
      if (mounted) {
        AppDialogs.error(context, message: e.response?.data?['message']?.toString() ?? e.message ?? 'Orders failed');
      }
    }
  }

  Future<void> _submit(String barcode) async {
    if (_orderId == null || _orderId!.isEmpty) {
      await AppDialogs.info(context, title: 'Order required', message: 'Select an order first.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await ApiClient.instance.dio.post('/scanner/scan', data: {
        'orderId': _orderId,
        'barcode': barcode,
        'source': 'camera',
      });
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      final result = data is Map ? data['result']?.toString() : null;
      setState(() => _lastResult = '$barcode → $result');
      if (result == 'matched') {
        await AppDialogs.success(context, message: 'Matched: $barcode');
      } else {
        await AppDialogs.info(context, title: 'Scan', message: '$result — $barcode');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message)
          : e.message;
      if (e.response?.statusCode == 409) {
        await AppDialogs.duplicateScan(context, message: msg?.toString() ?? 'Duplicate');
      } else {
        await AppDialogs.error(context, message: msg?.toString() ?? 'Scan failed');
      }
      setState(() => _lastResult = 'ERR: $msg');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(Map<String, dynamic> o) {
    final name = o['customerName'] ?? o['marketplaceOrderId'] ?? o['id'];
    final st = o['status'] ?? '';
    return '$name · $st';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Scanner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          KpiStrip(items: [
            KpiItem('Orders', '${_orders.length}'),
            KpiItem('Selected', _orderId == null ? 'None' : 'Yes', hint: _orderId == null ? 'pick order' : 'ready'),
            KpiItem('Last', _lastResult == null || _lastResult!.isEmpty ? '—' : 'OK'),
            KpiItem('Device', 'Camera', hint: 'live'),
          ]),
          const SizedBox(height: 12),
          if (_loadingOrders)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              value: _orderId,
              decoration: const InputDecoration(
                labelText: 'Order',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _orders
                  .map((o) => DropdownMenuItem(
                        value: o['id']?.toString(),
                        child: Text(_label(o), overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _orderId = v),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Manual barcode / SKU',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _submit(v.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => _submit(_manualCtrl.text.trim()),
                child: const Text('Scan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: Text(_cameraOn ? 'Camera ON' : 'Camera OFF'),
                selected: _cameraOn,
                onSelected: (v) => setState(() => _cameraOn = v),
              ),
              const SizedBox(width: 8),
              TextButton.icon(onPressed: _loadOrders, icon: const Icon(Icons.refresh), label: const Text('Orders')),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 8),
            Text(_lastResult!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          if (_cameraOn)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
                    if (raw != null && raw.isNotEmpty) _submit(raw);
                  },
                ),
              ),
            )
          else
            const Expanded(child: Center(child: Text('Turn camera on or enter barcode manually'))),
        ],
      ),
    );
  }
}
