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
  final _code = TextEditingController();
  final _pass = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _msg;

  Future<void> _send() async {
    setState(() { _loading = true; _msg = null; });
    try {
      final res = await ApiClient.instance.dio.post('/auth/forgot-password', data: {
        'email': _email.text.trim(),
      });
      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final dev = data is Map ? data['devCode'] : null;
      setState(() {
        _codeSent = true;
        _msg = dev != null ? 'Dev code: $dev' : 'If the email exists, a code was sent.';
      });
    } on DioException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    setState(() { _loading = true; _msg = null; });
    try {
      await ApiClient.instance.dio.post('/auth/reset-password', data: {
        'email': _email.text.trim(),
        'code': _code.text.trim(),
        'newPassword': _pass.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset — please login')),
      );
      context.go('/login');
    } on DioException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password', border: OutlineInputBorder()),
                  ),
                ],
                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(_msg!, style: const TextStyle(color: Colors.blueGrey)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : (_codeSent ? _reset : _send),
                  child: Text(_codeSent ? 'Reset Password' : 'Send Code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}