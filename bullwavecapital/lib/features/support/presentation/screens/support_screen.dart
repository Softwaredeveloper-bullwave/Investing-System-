import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/support_contact.dart';
import '../../../../core/theme/colors.dart';
import '../widgets/support_contact_sheets.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../profile/presentation/provider/referral_support_provider.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Support'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Row(
                  children: [
                    const Icon(Icons.headset_mic, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How can we help?',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                          ),
                          Text(
                            'Call or SMS ${SupportContact.displayPhone}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                          Text(
                            SupportContact.email,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Row(
              children: [
                Expanded(
                  child: _SupportAction(
                    icon: Icons.sms_outlined,
                    label: 'Message',
                    onTap: () => SupportContactSheets.showSms(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SupportAction(
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onTap: () => SupportContactSheets.showCall(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SupportAction(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    onTap: () => SupportContactSheets.showEmail(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Text('FAQ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.paddingSm),
            ...provider.faqs.map(
              (faq) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(faq.question, style: Theme.of(context).textTheme.titleMedium),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(faq.answer, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMd),
            Text('Raise a Ticket', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.paddingSm),
            ...provider.tickets.map(
              (ticket) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ticket.subject),
                  subtitle: Text('Created: ${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ticket.status == 'Open'
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ticket.status,
                      style: TextStyle(
                        color: ticket.status == 'Open' ? AppColors.warning : AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMd),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await context.read<SupportProvider>().raiseTicket(
                      'General inquiry',
                      message: 'Raised from mobile app',
                    );
                if (context.mounted && success) {
                  AppSnackbar.success(context, 'Ticket raised successfully');
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Raise New Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SupportAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
