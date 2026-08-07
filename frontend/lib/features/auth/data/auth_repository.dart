import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      if (deviceId != null) 'deviceId': deviceId,
    });

    final body = response.data;
    if (body is! Map) throw Exception('Invalid login response');

    // Handle both {data: {...}} and flat response
    final data = (body['data'] is Map) ? body['data'] as Map<String, dynamic> : body as Map<String, dynamic>;

    final access = data['accessToken']?.toString();
    final refresh = data['refreshToken']?.toString();

    if (access == null || access.isEmpty) {
      throw Exception('Login response missing accessToken. Got keys: ${data.keys}');
    }

    await SecureStorage.instance.saveTokens(
      accessToken: access,
      refreshToken: refresh ?? '',
    );
    return data;
  }

  Future<void> logout() async {
    try {
      final refresh = await SecureStorage.instance.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _dio.post('/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {}
    await SecureStorage.instance.clear();
  }
}