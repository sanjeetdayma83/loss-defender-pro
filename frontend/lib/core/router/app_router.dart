import '../../features/auth/presentation/sessions_screen.dart';
import 'package:go_router/go_router.dart';
import '../shell/app_shell.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/recording/presentation/recording_screen.dart';
import '../../features/dispatch/presentation/dispatch_screen.dart';
import '../../features/warehouses/presentation/warehouses_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/returns/presentation/returns_screen.dart';
import '../../features/evidence/presentation/evidence_screen.dart';
import '../../features/claims/presentation/claims_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) async {
    final loggedIn = await SecureStorage.instance.hasToken();
    final goingAuth = state.uri.path == '/login' || state.uri.path == '/register';
    if (!loggedIn && !goingAuth) return '/login';
    if (loggedIn && goingAuth) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
        GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
        GoRoute(path: '/scanner', builder: (_, _) => const ScannerScreen()),
        GoRoute(path: '/recording', builder: (_, _) => const RecordingScreen()),
        GoRoute(path: '/dispatch', builder: (_, _) => const DispatchScreen()),
        GoRoute(path: '/warehouses', builder: (_, _) => const WarehousesScreen()),
        GoRoute(path: '/users', builder: (_, _) => const UsersScreen()),
        GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsScreen()),
        GoRoute(path: '/returns', builder: (_, _) => const ReturnsScreen()),
        GoRoute(path: '/evidence', builder: (_, _) => const EvidenceScreen()),
        GoRoute(path: '/claims', builder: (_, _) => const ClaimsScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/sessions', builder: (_, _) => const SessionsScreen()),
      ],
    ),
  ],
);