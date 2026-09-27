import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openWhatsApp(BuildContext context, String phone, String message) async {
  final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يوجد رقم WhatsApp مسجل')),
    );
    return;
  }
  final uri = Uri.parse(
    'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح WhatsApp')),
    );
  }
}
