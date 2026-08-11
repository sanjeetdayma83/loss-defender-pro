import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() { _busy = true; _msg = null; });
    try {
      await ApiClient.instance.dio.post('/auth/forgot-password', data: {'email': email});
      if (!mounted) return;
      setState(() => _msg = 'If the email exists, a code was sent.');
      context.push('/reset-password', extra: email);
    } on DioException catch (e) {
      setState(() => _msg = e.response?.data?['message']?.toString() ?? e.message ?? 'Failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your account email. We will send a one-time code.'),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send code'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!),
            ],
            TextButton(onPressed: () => context.go('/login'), child: const Text('Back to login')),
          ],
        ),
      ),
    );
  }
}
