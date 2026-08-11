import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? email;
  const VerifyEmailScreen({super.key, this.email});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await ApiClient.instance.dio.post('/auth/verify-email', data: {
        'email': _email.text.trim(),
        'code': _code.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email verified')));
      context.go('/login');
    } on DioException catch (e) {
      setState(() => _msg = e.response?.data?['message']?.toString() ?? e.message ?? 'Failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'OTP code', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('Verify')),
            if (_msg != null) ...[const SizedBox(height: 12), Text(_msg!, style: const TextStyle(color: Colors.red))],
          ],
        ),
      ),
    );
  }
}
