import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_form_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _company;
  bool _loading = true;
  String? _error;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? user;
      try {
        final r = await ApiClient.instance.dio.get('/users/me');
        final body = r.data;
        final data = body is Map && body['data'] != null ? body['data'] : body;
        if (data is Map) user = Map<String, dynamic>.from(data);
      } catch (_) {}

      Map<String, dynamic>? company;
      try {
        final r = await ApiClient.instance.dio.get('/companies/me');
        final body = r.data;
        final data = body is Map && body['data'] != null ? body['data'] : body;
        if (data is Map) company = Map<String, dynamic>.from(data);
      } catch (_) {}

      _nameCtrl.text = user?['name']?.toString() ?? '';
      _phoneCtrl.text = user?['phone']?.toString() ?? '';
      setState(() {
        _user = user;
        _company = company;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    try {
      await ApiClient.instance.dio.patch('/users/me', data: {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      await AppDialogs.success(context, message: 'Profile updated');
      _load();
    } on DioException catch (e) {
      await AppDialogs.error(context,
          message: e.response?.data?['message']?.toString() ?? e.message ?? 'Failed');
    }
  }

  Future<void> _changePassword() async {
    final data = await AppFormDialogs.changePassword(context);
    if (data == null) return;
    try {
      await ApiClient.instance.dio.post('/auth/change-password', data: data);
      await AppDialogs.success(context, message: 'Password updated');
    } on DioException catch (e) {
      // fallback message if endpoint not ready
      await AppDialogs.error(context,
          message: e.response?.data?['message']?.toString() ??
              e.message ??
              'Change password API not available yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Profile, security and company preferences',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 16),
                Text('Email: ${_user?['email'] ?? '—'}',
                    style: const TextStyle(fontSize: 13)),
                Text('Role: ${_user?['role'] ?? '—'}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton(
                        onPressed: _saveProfile, child: const Text('Save Profile')),
                    const SizedBox(width: 12),
                    OutlinedButton(
                        onPressed: _changePassword,
                        child: const Text('Change Password')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Company',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                Text(_company?['companyName']?.toString() ?? '—',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Plan: ${_company?['plan'] ?? '—'}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}