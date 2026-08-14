import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/error/global_error.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  usePathUrlStrategy();
  runApp(const ProviderScope(child: LossDefenderApp()));
}

class LossDefenderApp extends ConsumerWidget {
  const LossDefenderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set global error handler for uncaught errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalErrorWidget(
        error: details.exception,
        stackTrace: details.stack,
        onRetry: () {
          // Trigger router refresh
        },
      );
    };

    return MaterialApp.router(
      title: 'Loss Defender Pro',
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ErrorBoundary(
          child: child ?? const SizedBox.shrink(),
          errorBuilder: (error, stackTrace, onRetry) {
            return GlobalErrorWidget(
              error: error,
              stackTrace: stackTrace,
              onRetry: onRetry,
            );
          },
        );
      },
    );
  }
}
