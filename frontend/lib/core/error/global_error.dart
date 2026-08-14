import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const GlobalErrorWidget({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  String get _userMessage {
    final errorStr = error.toString();
    
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return 'Your session has expired. Please log in again.';
    } else if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return 'You don\'t have permission to access this resource.';
    } else if (errorStr.contains('404') || errorStr.contains('Not Found')) {
      return 'The requested resource was not found.';
    } else if (errorStr.contains('429') || errorStr.contains('Too Many Requests')) {
      return 'Too many requests. Please wait a moment and try again.';
    } else if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503') || errorStr.contains('504')) {
      return 'Something went wrong on our end. Please try again later.';
    } else if (errorStr.contains('Connection refused') || errorStr.contains('Network') || errorStr.contains('SocketException')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorStr.contains('400') || errorStr.contains('Bad Request')) {
      return 'Invalid request. Please check your input and try again.';
    } else if (errorStr.contains('409') || errorStr.contains('Conflict')) {
      return 'A conflict occurred. This item may already exist.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  String get _supportId {
    final hash = error.toString().hashCode.abs().toString().padLeft(8, '0');
    return 'LDP-${hash.substring(0, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _userMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onRetry != null)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Log In'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Support ID: ${_supportId}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper to catch errors in the widget tree
class ErrorBoundary extends ConsumerStatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace, VoidCallback onRetry)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
  }

  Widget _errorBuilder(Object error, StackTrace? stackTrace) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(error, stackTrace, () {
        setState(() {
          _error = null;
          _stackTrace = null;
        });
      });
    }
    return GlobalErrorWidget(
      error: error,
      stackTrace: stackTrace,
      onRetry: () {
        setState(() {
          _error = null;
          _stackTrace = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _errorBuilder(_error!, _stackTrace!);
    }
    return widget.child;
  }
}

/// Provider for global error handling
final globalErrorProvider = StateProvider<GlobalErrorState>((ref) => GlobalErrorState());

class GlobalErrorState {
  final Object? error;
  final StackTrace? stackTrace;
  final bool isShowing;

  GlobalErrorState({
    this.error,
    this.stackTrace,
    this.isShowing = false,
  });

  GlobalErrorState copyWith({
    Object? error,
    StackTrace? stackTrace,
    bool? isShowing,
  }) {
    return GlobalErrorState(
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      isShowing: isShowing ?? this.isShowing,
    );
  }

  void clear() {
    // Reset state
  }
}

/// Mixin to add error handling to any widget
mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  void handleError(Object error, StackTrace stackTrace) {
    debugPrint('Error: $error');
    debugPrintStack(stackTrace: stackTrace);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getUserMessage(error)),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {},
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _getUserMessage(Object error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return 'Your session has expired. Please log in again.';
    } else if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return 'You don\'t have permission to access this resource.';
    } else if (errorStr.contains('404') || errorStr.contains('Not Found')) {
      return 'The requested resource was not found.';
    } else if (errorStr.contains('429') || errorStr.contains('Too Many Requests')) {
      return 'Too many requests. Please wait a moment and try again.';
    } else if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503') || errorStr.contains('504')) {
      return 'Something went wrong on our end. Please try again later.';
    } else if (errorStr.contains('Connection refused') || errorStr.contains('Network') || errorStr.contains('SocketException')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorStr.contains('400') || errorStr.contains('Bad Request')) {
      return 'Invalid request. Please check your input and try again.';
    } else if (errorStr.contains('409') || errorStr.contains('Conflict')) {
      return 'A conflict occurred. This item may already exist.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
}