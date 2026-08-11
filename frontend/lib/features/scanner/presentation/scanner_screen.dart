import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../recording/presentation/recording_session_page.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';
import 'camera_scanner_page.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _manualCtrl = TextEditingController();
  final _manualFocus = FocusNode();
  List<Map<String, dynamic>> _orders = [];
  String? _orderId;
  bool _loadingOrders = true;
  bool _busy = false;
  String? _lastResult;
  String? _lastBarcode;
  DateTime? _lastScanAt;
  List<Map<String, dynamic>> _itemProgress = [];

  static const _debounce = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final res = await ApiClient.instance.dio.get('/orders');
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      final all = (data is List ? data : <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final list = all.where((o) {
        final s = (o['status'] ?? '').toString();
        return ['packing', 'queued', 'synced', 'recording', 'scanned'].contains(s);
      }).toList();
      setState(() {
        _orders = list.isNotEmpty ? list : all;
        if (_orders.isNotEmpty && _orderId == null) {
          _orderId = _orders.first['id']?.toString();
          _extractItems(_orders.first);
        }
        _loadingOrders = false;
      });
    } on DioException catch (e) {
      setState(() => _loadingOrders = false);
      if (!mounted) return;
      await AppDialogs.error(context,
          message: e.response?.data?['message']?.toString() ?? e.message ?? 'Orders failed');
    }
  }

  void _extractItems(Map<String, dynamic>? o) {
    if (o == null) {
      _itemProgress = [];
      return;
    }
    final items = o['items'];
    if (items is List) {
      _itemProgress = items.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return {
          'sku': m['sku']?.toString() ?? m['skuCode']?.toString() ?? '—',
          'name': m['name']?.toString() ?? m['title']?.toString() ?? '',
          'qty': m['qty'] ?? m['quantity'] ?? 1,
          'scannedQty': m['scannedQty'] ?? 0,
          'status': m['status']?.toString() ?? '',
        };
      }).toList();
    } else {
      _itemProgress = [];
    }
  }

  bool _shouldAccept(String barcode) {
    final now = DateTime.now();
    if (_lastBarcode == barcode &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < _debounce) {
      return false;
    }
    _lastBarcode = barcode;
    _lastScanAt = now;
    return true;
  }

  Future<void> _submit(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;
    if (_orderId == null || _orderId!.isEmpty) {
      if (!mounted) return;
      await AppDialogs.info(context, title: 'Order required', message: 'Select an order first.');
      return;
    }
    if (!_shouldAccept(code)) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await ApiClient.instance.dio.post('/scanner/scan', data: {
        'orderId': _orderId,
        'barcode': code,
        'source': 'camera',
      });
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      final result = data is Map ? data['result']?.toString() : null;
      setState(() => _lastResult = '$code → $result');
      await _offerRecording();

      if (data is Map && data['order'] is Map) {
        _extractItems(Map<String, dynamic>.from(data['order'] as Map));
      } else if (data is Map && data['items'] is List) {
        _extractItems({'items': data['items']});
      }

      if (!mounted) return;
      if (result == 'matched') {
        await AppDialogs.success(context, message: 'Matched: $code');
      } else {
        await AppDialogs.info(context, title: 'Scan', message: '$result — $code');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message)
          : e.message;
      if (!mounted) return;
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

  Future<void> _openFullCamera() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScannerPage()),
    );
    if (raw != null && raw.isNotEmpty) await _submit(raw);
  }

  String _label(Map<String, dynamic> o) {
    final name = o['customerName'] ?? o['marketplaceOrderId'] ?? o['id'];
    final st = o['status'] ?? '';
    return '$name · $st';
  }

  
    Future<void> _offerRecording() async {
    final oid = _orderId;
    if (oid == null || oid.isEmpty) return;
    String? wh;
    for (final o in _orders) {
      if (o['id']?.toString() == oid) {
        wh = o['warehouseId']?.toString();
        if (wh == null && o['warehouse'] is Map) {
          wh = o['warehouse']['id']?.toString();
        }
        break;
      }
    }
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan successful'),
        content: const Text('Start recording for this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start recording')),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RecordingSessionPage(orderId: oid, warehouseId: wh),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Scanner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Orders ${_orders.length} · Selected ${_orderId == null ? 'None' : 'Yes'} · USB gun: focus field below',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_loadingOrders)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              initialValue: _orderId,
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
              onChanged: (v) {
                final o = _orders.where((e) => e['id']?.toString() == v).cast<Map<String, dynamic>?>().firstOrNull;
                setState(() {
                  _orderId = v;
                  _extractItems(o);
                });
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  focusNode: _manualFocus,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (camera / USB gun)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      _submit(v.trim());
                      _manualCtrl.clear();
                      _manualFocus.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        _submit(_manualCtrl.text);
                        _manualCtrl.clear();
                        _manualFocus.requestFocus();
                      },
                child: const Text('Scan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _openFullCamera,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Full camera'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Orders'),
              ),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 8),
            Text(_lastResult!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          const Text('Line items', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Expanded(
            child: _itemProgress.isEmpty
                ? const Center(
                    child: Text(
                      'Select order — items show when API returns them.\nUSB gun: keep focus in barcode field.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _itemProgress.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _itemProgress[i];
                      final qty = it['qty'] ?? 1;
                      final scanned = it['scannedQty'] ?? 0;
                      final done = scanned is num && qty is num && scanned >= qty;
                      return ListTile(
                        dense: true,
                        title: Text('${it['sku']} · ${it['name']}'),
                        subtitle: Text('Scanned $scanned / $qty · ${it['status']}'),
                        trailing: Icon(
                          done ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: done ? Colors.green : AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
