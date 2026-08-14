import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  // Company fields
  final _companyNameCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyWebsiteCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _timezoneCtrl.dispose();
    _currencyCtrl.dispose();
    _addressCtrl.dispose();
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

      _companyNameCtrl.text = company?['companyName']?.toString() ?? '';
      _companyPhoneCtrl.text = company?['phone']?.toString() ?? '';
      _companyEmailCtrl.text = company?['email']?.toString() ?? '';
      _companyWebsiteCtrl.text = company?['website']?.toString() ?? '';
      _gstCtrl.text = company?['gst']?.toString() ?? '';
      _panCtrl.text = company?['pan']?.toString() ?? '';
      _timezoneCtrl.text = company?['timezone']?.toString() ?? 'Asia/Kolkata';
      _currencyCtrl.text = company?['currency']?.toString() ?? 'INR';
      _addressCtrl.text = company?['address'] is Map
          ? (company!['address'] as Map).entries.map((e) => '${e.key}: ${e.value}').join(', ')
          : company?['address']?.toString() ?? '';

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

  Future<void> _saveCompany() async {
    try {
      // Parse address string back to JSON
      Map<String, dynamic>? addressJson;
      if (_addressCtrl.text.trim().isNotEmpty) {
        addressJson = {};
        for (final part in _addressCtrl.text.split(',')) {
          final kv = part.split(':');
          if (kv.length == 2) {
            addressJson[kv[0].trim()] = kv[1].trim();
          }
        }
      }

      await ApiClient.instance.dio.patch('/companies/me', data: {
        'companyName': _companyNameCtrl.text.trim(),
        'phone': _companyPhoneCtrl.text.trim(),
        'email': _companyEmailCtrl.text.trim(),
        if (_companyWebsiteCtrl.text.trim().isNotEmpty) 'website': _companyWebsiteCtrl.text.trim(),
        if (_gstCtrl.text.trim().isNotEmpty) 'gst': _gstCtrl.text.trim(),
        if (_panCtrl.text.trim().isNotEmpty) 'pan': _panCtrl.text.trim(),
        if (_timezoneCtrl.text.trim().isNotEmpty) 'timezone': _timezoneCtrl.text.trim(),
        if (_currencyCtrl.text.trim().isNotEmpty) 'currency': _currencyCtrl.text.trim(),
        if (addressJson != null) 'address': addressJson,
      });
      await AppDialogs.success(context, message: 'Company settings updated');
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

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Row(
              children: [
                const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                const Text('Profile, security, company & notifications', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Company'),
              Tab(text: 'Notifications'),
            ],
            labelStyle: TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Profile Tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 16),
                            Text('Email: ${_user?['email'] ?? '—'}', style: const TextStyle(fontSize: 13)),
                            Text('Role: ${_user?['role'] ?? '—'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                FilledButton(onPressed: _saveProfile, child: const Text('Save Profile')),
                                const SizedBox(width: 12),
                                OutlinedButton(onPressed: _changePassword, child: const Text('Change Password')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sessions section
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
                            const Text('Active Sessions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => context.go('/sessions'),
                              icon: const Icon(Icons.devices_outlined, size: 18),
                              label: const Text('Manage Sessions & Devices'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Company Tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            const Text('Company Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 16),
                            TextField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: 'Company Name *', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _companyPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _companyEmailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _companyWebsiteCtrl, decoration: const InputDecoration(labelText: 'Website', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _gstCtrl, decoration: const InputDecoration(labelText: 'GST Number', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _panCtrl, decoration: const InputDecoration(labelText: 'PAN', border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _timezoneCtrl, decoration: const InputDecoration(labelText: 'Timezone', border: OutlineInputBorder()))),
                                const SizedBox(width: 12),
                                Expanded(child: TextField(controller: _currencyCtrl, decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _addressCtrl,
                              decoration: const InputDecoration(labelText: 'Address (key: value, key: value)', border: OutlineInputBorder()),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: _saveCompany, child: const Text('Save Company Settings')),
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
                            const Text('Plan & Limits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 12),
                            Text(_company?['companyName']?.toString() ?? '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('Plan: ${_company?['plan'] ?? '—'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            Text('Storage: ${_company?['storageUsed'] ?? 0} / ${_company?['storageQuota'] ?? 0} bytes', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Notifications Tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 16),
                            _NotificationTile('Email Notifications', 'Receive email alerts for claims, dispatches, and system updates', true, () {}),
                            _NotificationTile('Push Notifications', 'Receive push notifications on mobile app', false, () {}),
                            _NotificationTile('SMS Alerts', 'Critical alerts via SMS (if configured)', false, () {}),
                            _NotificationTile('Weekly Digest', 'Weekly summary of warehouse operations', true, () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final VoidCallback onChanged;
  const _NotificationTile(this.title, this.subtitle, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      onChanged: (_) => onChanged(),
      activeColor: AppColors.accent,
      contentPadding: EdgeInsets.zero,
    );
  }
}