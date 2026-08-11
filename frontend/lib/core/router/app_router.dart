import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shell/app_shell.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/auth/presentation/accept_invite_screen.dart';
import '../../features/auth/presentation/sessions_screen.dart';
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
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction, size: 48, color: Colors.orange.shade700),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Coming soon on this branch', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) async {
    final loggedIn = await SecureStorage.instance.hasToken();
    final path = state.uri.path;
    const public = {
      '/login',
      '/register',
      '/forgot-password',
      '/reset-password',
      '/verify-email',
      '/accept-invite',
    };
    if (!loggedIn && !public.contains(path)) return '/login';
    if (loggedIn && (path == '/login' || path == '/register')) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
    GoRoute(
      path: '/reset-password',
      builder: (_, state) => ResetPasswordScreen(email: state.extra as String?),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (_, state) => VerifyEmailScreen(email: state.extra as String?),
    ),
    GoRoute(
      path: '/accept-invite',
      builder: (_, state) => AcceptInviteScreen(
        token: state.uri.queryParameters['token'] ?? state.extra as String?,
      ),
    ),
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
        GoRoute(path: '/marketplace', builder: (_, _) => const MarketplaceScreen()),
        GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/sessions', builder: (_, _) => const SessionsScreen()),
        GoRoute(path: '/admin', builder: (_, _) => const _PlaceholderScreen('Admin')),
        GoRoute(path: '/billing', builder: (_, _) => const _PlaceholderScreen('Billing')),
        GoRoute(path: '/support', builder: (_, _) => const _PlaceholderScreen('Support')),
      ],
    ),
  ],
);
