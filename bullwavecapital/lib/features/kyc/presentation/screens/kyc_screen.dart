import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/image_source_bottom_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/kyc_provider.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'KYC Verification'),
      body: Consumer<KycProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${provider.currentStep + 1} of ${provider.totalSteps}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingLg),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.steps.length,
                    itemBuilder: (context, index) {
                      final step = provider.steps[index];
                      final key = step['key']!;
                      final title = step['title']!;
                      final isUploaded = provider.isStepUploaded(key);
                      final isCurrent = index == provider.currentStep && !isUploaded;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isCurrent
                            ? AppColors.primary.withValues(alpha: 0.05)
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isUploaded
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              isUploaded ? Icons.check : Icons.upload_file,
                              color: isUploaded ? AppColors.success : AppColors.primary,
                            ),
                          ),
                          title: Text(title),
                          subtitle: Text(isUploaded ? 'Uploaded' : 'Tap to upload'),
                          trailing: isUploaded
                              ? const Icon(Icons.check_circle, color: AppColors.success)
                              : const Icon(Icons.upload_file_outlined, color: AppColors.primary),
                          onTap: () {
                            ImageSourceBottomSheet.show(
                              context,
                              documentName: title,
                              onUploaded: () => provider.uploadDocument(key),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                PrimaryButton(
                  label: 'Submit KYC',
                  isLoading: provider.isSubmitting,
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await provider.submit();
                    if (!context.mounted) return;
                    if (success) {
                      router.push(AppRoutes.kycSuccess);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Please upload all documents')),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
