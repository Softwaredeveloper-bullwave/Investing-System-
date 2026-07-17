import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/primary_button.dart';

class DepositSuccessScreen extends StatelessWidget {
  const DepositSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 72),
              ),
              const SizedBox(height: AppDimensions.paddingLg),
              Text('Deposit Successful!', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Your deposit has been processed successfully and will reflect in your wallet shortly.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingXl),
              PrimaryButton(
                label: 'Go to Wallet',
                onPressed: () => context.go(AppRoutes.wallet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
