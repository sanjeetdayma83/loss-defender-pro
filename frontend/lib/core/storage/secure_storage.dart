import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web → SharedPreferences | Mobile/Desktop → flutter_secure_storage
class SecureStorage {
  SecureStorage._internal();
  static final SecureStorage instance = SecureStorage._internal();

  final _secure = const FlutterSecureStorage();

  static const _access = 'ldp_access_token';
  static const _refresh = 'ldp_refresh_token';
  static const _userKey = 'cached_user_json';
  static const _companyKey = 'cached_company_json';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_access, accessToken);
      await prefs.setString(_refresh, refreshToken);
    } else {
      await _secure.write(key: _access, value: accessToken);
      await _secure.write(key: _refresh, value: refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_access);
    }
    return _secure.read(key: _access);
  }

  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refresh);
    }
    return _secure.read(key: _refresh);
  }

  Future<bool> hasToken() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_access);
      await prefs.remove(_refresh);
      await prefs.remove(_userKey);
      await prefs.remove(_companyKey);
    } else {
      await _secure.delete(key: _access);
      await _secure.delete(key: _refresh);
      await _secure.delete(key: _userKey);
      await _secure.delete(key: _companyKey);
    }
  }

  Future<void> saveUserJson(String json) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json);
    } else {
      await _secure.write(key: _userKey, value: json);
    }
  }

  Future<String?> readUserJson() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userKey);
    }
    return _secure.read(key: _userKey);
  }

  Future<void> saveCompanyJson(String json) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_companyKey, json);
    } else {
      await _secure.write(key: _companyKey, value: json);
    }
  }

  Future<String?> readCompanyJson() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_companyKey);
    }
    return _secure.read(key: _companyKey);
  }
}