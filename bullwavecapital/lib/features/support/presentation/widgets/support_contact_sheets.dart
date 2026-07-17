import 'package:flutter/material.dart';

import '../../../../core/constants/support_contact.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/support_launcher.dart';
import '../../../../core/widgets/primary_button.dart';

/// Banking-style compose sheets before opening SMS / Call / Email.
class SupportContactSheets {
  SupportContactSheets._();

  static void showSms(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmsQuerySheet(
        onSend: (message) async {
          Navigator.of(ctx).pop();
          await SupportLauncher.openSms(context, message: message);
        },
      ),
    );
  }

  static void showCall(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CallQuerySheet(
        onCall: () async {
          Navigator.of(ctx).pop();
          await SupportLauncher.openCall(context);
        },
      ),
    );
  }

  static void showEmail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmailQuerySheet(
        onSend: (subject, message) async {
          Navigator.of(ctx).pop();
          await SupportLauncher.openEmail(context, subject: subject, body: message);
        },
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isLoading;

  const _SheetShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: iconColor.withValues(alpha: 0.12),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.green,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
              const SizedBox(height: 20),
              PrimaryButton(
                label: actionLabel,
                icon: icon,
                isLoading: isLoading,
                onPressed: isLoading ? null : onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmsQuerySheet extends StatefulWidget {
  final Future<void> Function(String message) onSend;

  const _SmsQuerySheet({required this.onSend});

  @override
  State<_SmsQuerySheet> createState() => _SmsQuerySheetState();
}

class _SmsQuerySheetState extends State<_SmsQuerySheet> {
  late final TextEditingController _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: 'Hi BullWave team,\n\nI need help with:\n\n',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await widget.onSend(_controller.text);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.sms_outlined,
      iconColor: AppColors.green,
      title: 'Message Support',
      subtitle: SupportContact.displayPhone,
      actionLabel: 'Open Messages',
      isLoading: _loading,
      onAction: _submit,
      child: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 4,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          labelText: 'Your message',
          hintText: 'Describe your issue...',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CallQuerySheet extends StatefulWidget {
  final Future<void> Function() onCall;

  const _CallQuerySheet({required this.onCall});

  @override
  State<_CallQuerySheet> createState() => _CallQuerySheetState();
}

class _CallQuerySheetState extends State<_CallQuerySheet> {
  bool _loading = false;

  Future<void> _call() async {
    setState(() => _loading = true);
    await widget.onCall();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.phone_outlined,
      iconColor: AppColors.primary,
      title: 'Call Support',
      subtitle: SupportContact.displayPhone,
      actionLabel: 'Call Now',
      isLoading: _loading,
      onAction: _call,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speak with our team',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap Call Now to open your phone dialer. Standard call charges may apply.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailQuerySheet extends StatefulWidget {
  final Future<void> Function(String subject, String message) onSend;

  const _EmailQuerySheet({required this.onSend});

  @override
  State<_EmailQuerySheet> createState() => _EmailQuerySheetState();
}

class _EmailQuerySheetState extends State<_EmailQuerySheet> {
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: SupportContact.emailSubject);
    _messageController = TextEditingController(
      text: 'Hi BullWave team,\n\nI need help with:\n\n',
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await widget.onSend(_subjectController.text, _messageController.text);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.email_outlined,
      iconColor: AppColors.brandOrange,
      title: 'Email Support',
      subtitle: SupportContact.email,
      actionLabel: 'Open Email App',
      isLoading: _loading,
      onAction: _submit,
      child: Column(
        children: [
          TextField(
            controller: _subjectController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 5,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your message',
              hintText: 'Describe your issue...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
