import 'package:dio/dio.dart';
import '../network/api_client.dart';

class RbacState {
  final String role;
  final String plan;
  final List<String> permissions;
  final List<String> features;
  final List<String> navAllowed;
  final Map<String, dynamic> limits;

  RbacState({
    required this.role,
    required this.plan,
    required this.permissions,
    required this.features,
    required this.navAllowed,
    required this.limits,
  });

  bool can(String permission) => permissions.contains(permission);
  bool hasFeature(String f) => features.contains(f);
  bool routeAllowed(String path) {
    if (navAllowed.isEmpty) return true;
    return navAllowed.any((p) => path == p || path.startsWith(p));
  }

  static RbacState empty() => RbacState(
        role: 'packing_operator',
        plan: 'starter',
        permissions: const [],
        features: const ['core'],
        navAllowed: const [],
        limits: const {},
      );

  static Future<RbacState> load() async {
    try {
      final res = await ApiClient.instance.dio.get('/rbac/permissions');
      final d = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      if (d is! Map) return RbacState.empty();
      return RbacState(
        role: d['role']?.toString() ?? 'packing_operator',
        plan: d['plan']?.toString() ?? 'starter',
        permissions: (d['permissions'] is List)
            ? (d['permissions'] as List).map((e) => e.toString()).toList()
            : [],
        features: (d['features'] is List)
            ? (d['features'] as List).map((e) => e.toString()).toList()
            : [],
        navAllowed: (d['navAllowed'] is List)
            ? (d['navAllowed'] as List).map((e) => e.toString()).toList()
            : [],
        limits: d['limits'] is Map ? Map<String, dynamic>.from(d['limits'] as Map) : {},
      );
    } on DioException {
      return RbacState.empty();
    }
  }
}
