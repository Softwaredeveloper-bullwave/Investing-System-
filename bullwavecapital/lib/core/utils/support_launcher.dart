import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/support_contact.dart';

/// Opens native SMS, phone, and email apps with pre-filled support queries.
class SupportLauncher {
  SupportLauncher._();

  static const _defaultMessage =
      'Hi BullWave team,\n\nI need help with:\n\n';

  static Future<bool> openSms(BuildContext context, {String? message}) async {
    final body = message?.trim().isNotEmpty == true ? message!.trim() : _defaultMessage;
    final phone = SupportContact.phone;

    final uris = <Uri>[
      if (!kIsWeb && Platform.isAndroid)
        Uri.parse('smsto:$phone?body=${Uri.encodeComponent(body)}'),
      Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}'),
      Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': body},
      ),
    ];

    return _launchFirst(context, uris, 'No SMS app found. Install Messages and try again.');
  }

  static Future<bool> openCall(BuildContext context) async {
    final phone = SupportContact.phone;
    final uris = [
      Uri.parse('tel:$phone'),
      Uri(scheme: 'tel', path: phone),
    ];
    return _launchFirst(context, uris, 'Could not open phone dialer.');
  }

  static Future<bool> openEmail(
    BuildContext context, {
    String? subject,
    String? body,
  }) async {
    final sub = subject?.trim().isNotEmpty == true
        ? subject!.trim()
        : SupportContact.emailSubject;
    final message = body?.trim().isNotEmpty == true ? body!.trim() : _defaultMessage;
    final email = SupportContact.email;

    final uris = <Uri>[
      Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent(sub)}&body=${Uri.encodeComponent(message)}',
      ),
      Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {'subject': sub, 'body': message},
      ),
    ];

    return _launchFirst(context, uris, 'No email app found. Install Gmail/Outlook and try again.');
  }

  static Future<bool> _launchFirst(
    BuildContext context,
    List<Uri> uris,
    String errorMessage,
  ) async {
    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
        final ok = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (ok) return true;
      } catch (_) {
        continue;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
