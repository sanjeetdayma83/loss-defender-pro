import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, dynamic> _contacts = {
    'supportEmail': 'support@lossdefender.in',
    'infoEmail': 'info@lossdefender.in',
    'whatsapp': '8278124406',
    'whatsappUrl': 'https://wa.me/918278124406',
    'hours': 'Mon–Sat 10:00–19:00 IST',
  };
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final res = await ApiClient.instance.dio.get('/support/contacts');
      final d = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      if (d is Map) setState(() => _contacts = Map<String, dynamic>.from(d));
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }

  Future<void> _submit() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.dio.post('/support/ticket', data: {
        'subject': _subject.text.trim().isEmpty ? 'Support request' : _subject.text.trim(),
        'message': _message.text.trim(),
        'category': _category,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket sent. We will reply on ${_contacts['supportEmail']}')),
        );
        _subject.clear();
        _message.clear();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message']?.toString() ?? 'Failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final support = _contacts['supportEmail']?.toString() ?? 'support@lossdefender.in';
    final info = _contacts['infoEmail']?.toString() ?? 'info@lossdefender.in';
    final wa = _contacts['whatsapp']?.toString() ?? '8278124406';
    final waUrl = _contacts['whatsappUrl']?.toString() ?? 'https://wa.me/918278124406';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Help & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(_contacts['hours']?.toString() ?? 'Mon–Sat 10:00–19:00 IST',
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.email_outlined, color: AppColors.accent),
            title: const Text('Support email'),
            subtitle: Text(support),
            trailing: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () => _copy(support)),
            onTap: () => _open('mailto:$support'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Info / sales'),
            subtitle: Text(info),
            trailing: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () => _copy(info)),
            onTap: () => _open('mailto:$info'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('WhatsApp support'),
            subtitle: Text('+$wa'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(waUrl),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Send a ticket', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('General')),
            DropdownMenuItem(value: 'billing', child: Text('Billing')),
            DropdownMenuItem(value: 'technical', child: Text('Technical')),
            DropdownMenuItem(value: 'claim', child: Text('Claims / Evidence')),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'general'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _subject,
          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: Text(_sending ? 'Sending…' : 'Submit ticket'),
        ),
        const SizedBox(height: 24),
        const Text('Quick help', style: TextStyle(fontWeight: FontWeight.w600)),
        const ListTile(
          dense: true,
          leading: Icon(Icons.check_circle_outline, size: 20),
          title: Text('Scan → Record → Evidence for packing proof'),
        ),
        const ListTile(
          dense: true,
          leading: Icon(Icons.check_circle_outline, size: 20),
          title: Text('Owner: Control Center for plans, roles & invites'),
        ),
        const ListTile(
          dense: true,
          leading: Icon(Icons.check_circle_outline, size: 20),
          title: Text('Billing via Razorpay on Plans screen'),
        ),
      ],
    );
  }
}
