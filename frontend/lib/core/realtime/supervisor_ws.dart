import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class SupervisorWebSocketService {
  SupervisorWebSocketService._();
  static final SupervisorWebSocketService instance = SupervisorWebSocketService._();

  IO.Socket? _socket;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _reconnectTimer;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get stream {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast(
      onListen: () => _connect(),
      onCancel: () {
        if (!_controller!.hasListener) _disconnect();
      },
    );
    return _controller!.stream;
  }

  Future<void> _connect() async {
    if (_socket != null || _disposed) return;

    final token = await SecureStorage.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[WS] No token available');
      return;
    }

    final baseUrl = ApiClient.instance.dio.options.baseUrl.replaceFirst('/api/v1', '');
    debugPrint('[WS] Connecting to $baseUrl/realtime');

    try {
      _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setPath('/realtime')
        .setAuth({'token': token})
        .enableAutoConnect()
        .build());

      _socket!.onConnect((_) {
        debugPrint('[WS] Connected: ${_socket!.id}');
        _socket!.emit('join', {'companyId': (await SecureStorage.instance.getUserJson())?.containsKey('companyId') == true});
      });

      _socket!.onDisconnect((_) {
        debugPrint('[WS] Disconnected');
        _scheduleReconnect();
      });

      _socket!.onConnectError((error) {
        debugPrint('[WS] Connect error: $error');
        _scheduleReconnect();
      });

      _socket!.onError((error) {
        debugPrint('[WS] Error: $error');
      });

      // Listen for events
      _socket!.on('order.status', (data) => _controller?.add({'type': 'order.status', 'data': data}));
      _socket!.on('notification', (data) => _controller?.add({'type': 'notification', 'data': data}));
      _socket!.on('recording.update', (data) => _controller?.add({'type': 'recording.update', 'data': data}));
      _socket!.on('alert', (data) => _controller?.add({'type': 'alert', 'data': data}));
    } catch (e) {
      debugPrint('[WS] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed) _connect();
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _controller?.close();
    _controller = null;
  }

  void dispose() {
    _disposed = true;
    _disconnect();
  }
}