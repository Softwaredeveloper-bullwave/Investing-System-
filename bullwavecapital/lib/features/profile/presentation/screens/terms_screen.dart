import 'package:flutter/material.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Terms & Conditions'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Text(
          _termsText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ),
    );
  }
}

const _termsText = '''
Terms & Conditions

Last updated: January 2025

By using BullWave Invest, you agree to these Terms and Conditions.

Investment Disclaimer
Investments are subject to market risks. Past performance is not indicative of future returns. Please read all scheme-related documents carefully before investing.

Eligibility
• You must be 18 years or older
• You must be a resident of India
• Valid KYC documentation is mandatory

Minimum Investment
The minimum investment amount varies by plan. The Premium Plan requires a minimum investment of ₹10,00,000.

Returns
Returns mentioned are indicative and based on historical performance. Actual returns may vary based on market conditions.

Withdrawal Policy
Profit withdrawals can be processed anytime. Principal withdrawal is subject to plan lock-in periods and applicable charges.

Governing Law
These terms are governed by the laws of India. Disputes shall be subject to the jurisdiction of courts in Mumbai.

Contact
Email: legal@bullwave.in
Phone: 1800-123-4567
''';
