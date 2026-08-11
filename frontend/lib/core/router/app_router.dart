import '../../features/support/presentation/support_screen.dart';
import '../../features/admin/presentation/owner_control_screen.dart';
import '../../features/billing/presentation/billing_screen.dart';
import '../../features/auth/presentation/sessions_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import 'package:flutter/material.dart';
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
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) async {
    final loggedIn = await SecureStorage.instance.hasToken();
    final path = state.uri.path;
    final goingAuth = path == '/login' ||
        path == '/register' ||
        path == '/forgot-password' ||
        path == '/reset-password' ||
        path == '/verify-email';
    if (!loggedIn && !goingAuth) return '/login';
    if (loggedIn && (path == '/login' || path == '/register')) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(
      path: '/reset-password',
      builder: (_, state) => ResetPasswordScreen(email: state.extra as String?),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (_, state) => VerifyEmailScreen(email: state.extra as String?),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
        GoRoute(path: '/scanner', builder: (_, __) => const ScannerScreen()),
        GoRoute(path: '/recording', builder: (_, __) => const RecordingScreen()),
        GoRoute(path: '/dispatch', builder: (_, __) => const DispatchScreen()),
        GoRoute(path: '/warehouses', builder: (_, __) => const WarehousesScreen()),
        GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
        GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
        GoRoute(path: '/returns', builder: (_, __) => const ReturnsScreen()),
        GoRoute(path: '/evidence', builder: (_, __) => const EvidenceScreen()),
        GoRoute(path: '/claims', builder: (_, __) => const ClaimsScreen()),
        GoRoute(path: '/marketplace', builder: (_, __) => const MarketplaceScreen()),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const OwnerControlScreen()),
        GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
        GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/sessions', builder: (_, __) => const SessionsScreen()),
      ],
    ),
  ],
);
