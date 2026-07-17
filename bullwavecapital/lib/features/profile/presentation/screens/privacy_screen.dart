import 'package:flutter/material.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Privacy Policy'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Text(
          _privacyText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ),
    );
  }
}

const _privacyText = '''
Privacy Policy

Last updated: January 2025

BullWave Invest ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information.

Information We Collect
• Personal identification information (Name, email, phone number, PAN, Aadhaar)
• Financial information (Bank account details, investment history)
• Device and usage information

How We Use Your Information
• To provide and maintain our investment services
• To process transactions and send notifications
• To comply with regulatory requirements (SEBI, RBI)
• To improve our services and user experience

Data Security
We implement industry-standard security measures including encryption, secure servers, and regular security audits to protect your data.

Your Rights
You have the right to access, correct, or delete your personal data. Contact us at privacy@bullwave.in for any privacy-related queries.

Contact Us
Email: privacy@bullwave.in
Phone: 1800-123-4567
''';
