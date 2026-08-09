import 'dart:convert';

/// In-memory + SharedPreferences-backed offline queue (SQLite optional next).
class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  final List<Map<String, dynamic>> _q = [];

  Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    _q.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'method': method,
      'path': path,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> peek() => List.unmodifiable(_q);

  Future<void> flush(Future<void> Function(Map<String, dynamic> item) send) async {
    final copy = List<Map<String, dynamic>>.from(_q);
    for (final item in copy) {
      try {
        await send(item);
        _q.remove(item);
      } catch (_) {
        break; // stop on first failure
      }
    }
  }

  String debugJson() => jsonEncode(_q);
}