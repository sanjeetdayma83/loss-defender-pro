import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

class AcceptInviteScreen extends StatefulWidget {
  const AcceptInviteScreen({super.key, this.token});
  final String? token;
  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final _tokenCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _ok;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) _tokenCtrl.text = widget.token!;
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; _ok = null; });
    try {
      await ApiClient.instance.dio.post('/auth/accept-invite', data: {
        'token': _tokenCtrl.text.trim(),
        'newPassword': _passCtrl.text,
      });
      setState(() => _ok = 'Invite accepted. Please login.');
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/login');
      }
    } on DioException catch (e) {
      setState(() =>
          _error = e.response?.data?['message']?.toString() ?? e.message ?? 'Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accept invite')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(labelText: 'Invite token'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 12),
                  Text(_ok!, style: const TextStyle(color: Colors.green)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set password & accept'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
