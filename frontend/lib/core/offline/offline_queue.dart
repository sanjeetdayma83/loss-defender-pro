import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal offline queue (docs offline-first).
/// Stores failed POST bodies and retries when online.
class OfflineQueue {
  static const _key = 'ldp_offline_queue';

  static Future<List<Map<String, dynamic>>> _read() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> _write(List<Map<String, dynamic>> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(items));
  }

  static Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final items = await _read();
    items.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'method': method,
      'path': path,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _write(items);
  }

  static Future<List<Map<String, dynamic>>> pending() => _read();

  static Future<void> remove(String id) async {
    final items = await _read();
    await _write(items.where((e) => e['id'] != id).toList());
  }
}
