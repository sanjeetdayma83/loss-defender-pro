import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://api.lossdefender.in/api/v1',
        ),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await SecureStorage.instance.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {}
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;

          // Avoid loop on auth endpoints
          final isAuthPath =
              path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh');

          if (status == 401 && !isAuthPath) {
            // Shared in-flight refresh: if a refresh is already running,
            // every concurrent 401 waits on the SAME future instead of
            // bailing out and clearing the session prematurely.
            final ok = await _sharedRefresh();
            if (ok) {
              try {
                final token = await SecureStorage.instance.getAccessToken();
                final req = error.requestOptions;
                req.headers['Authorization'] = 'Bearer $token';
                final clone = await _dio.fetch(req);
                return handler.resolve(clone);
              } catch (e) {
                await SecureStorage.instance.clear();
                return handler.next(error);
              }
            }
            await SecureStorage.instance.clear();
          } else if (status == 401 && isAuthPath) {
            await SecureStorage.instance.clear();
          }

          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  Dio get dio => _dio;

  // Holds the in-flight refresh call so concurrent 401s share one attempt.
  Future<bool>? _refreshFuture;

  Future<bool> _sharedRefresh() {
    _refreshFuture ??= _tryRefresh().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _tryRefresh() async {
    try {
      final refresh = await SecureStorage.instance.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return false;

      // Separate Dio — no interceptor loop
      final bare = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      final res = await bare.post(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );

      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      if (data is! Map) return false;

      final access = data['accessToken']?.toString();
      final newRefresh = data['refreshToken']?.toString() ?? refresh;
      if (access == null || access.isEmpty) return false;

      await SecureStorage.instance.saveTokens(
        accessToken: access,
        refreshToken: newRefresh,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
