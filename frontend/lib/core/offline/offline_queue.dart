import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

class OfflineQueue {
  static const _key = 'ldp_offline_queue';

  static Future<List<Map<String, dynamic>>> _read() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> _write(List<Map<String, dynamic>> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(items));
  }

  static Future<void> enqueue(String method, String path, Map<String, dynamic>? body) async {
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

  static Future<int> flush() async {
    final items = await _read();
    if (items.isEmpty) return 0;
    final remaining = <Map<String, dynamic>>[];
    var ok = 0;
    for (final item in items) {
      try {
        final method = (item['method'] as String).toUpperCase();
        final path = item['path'] as String;
        final body = item['body'] as Map<String, dynamic>?;
        final dio = ApiClient.instance.dio;
        if (method == 'POST') {
          await dio.post(path, data: body);
        } else if (method == 'PATCH') {
          await dio.patch(path, data: body);
        } else if (method == 'PUT') {
          await dio.put(path, data: body);
        } else {
          await dio.request(path, data: body, options: Options(method: method));
        }
        ok++;
      } catch (_) {
        remaining.add(item);
      }
    }
    await _write(remaining);
    return ok;
  }

  static Future<int> pendingCount() async => (await _read()).length;
}
