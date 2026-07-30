import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../provider/kyc_flow_provider.dart';

/// Instant KYC — typed PAN (Eko PAN Lite) + Aadhaar (Eko DigiLocker).
///
/// This replaces the old PAN-photo-upload screen: no documents to upload,
/// no waiting on an admin — PAN is checked against Eko instantly, and
/// Aadhaar is verified via a DigiLocker consent flow (the user briefly
/// leaves the app to authenticate with DigiLocker, then comes back and we
/// poll for the result). Step 2 only appears once step 1 succeeds.
class InstantKycScreen extends StatefulWidget {
  const InstantKycScreen({super.key});

  @override
  State<InstantKycScreen> createState() => _InstantKycScreenState();
}

class _InstantKycScreenState extends State<InstantKycScreen> {
  static const _kPollInterval = Duration(seconds: 5);
  static const _kMaxPolls = 60; // ~5 minutes

  final _panFormKey = GlobalKey<FormState>();
  final _panController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  Timer? _pollTimer;
  int _pollCount = 0;
  bool _digilockerOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final kyc = context.read<KycFlowProvider>();
      await kyc.loadInstantStatus();
      if (!mounted) return;
      final s = kyc.instantStatus;
      _panController.text = s.panNumber;
      _nameController.text = s.panName.isNotEmpty
          ? s.panName
          : (context.read<AuthProvider>().user?.name ?? '');
      // If PAN is already verified but Aadhaar isn't, and a DigiLocker
      // session was already started in a previous visit, resume polling.
      if (s.isPanVerified && !s.isAadhaarVerified) {
        _startPolling();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _panController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.green,
      ),
    );
  }

  Future<void> _verifyPan() async {
    if (!_panFormKey.currentState!.validate()) return;
    final kyc = context.read<KycFlowProvider>();
    final ok = await kyc.verifyPanInstant(
      panNumber: _panController.text,
      fullName: _nameController.text,
      dob: _dobController.text,
    );
    if (!mounted) return;
    if (ok) {
      _showSnack('PAN Verified Successfully');
    } else {
      _showSnack(kyc.instantError ?? 'PAN verification failed. Please try again.', isError: true);
    }
  }

  Future<void> _startAadhaar() async {
    final kyc = context.read<KycFlowProvider>();
    final url = await kyc.startAadhaarVerification();
    if (!mounted) return;
    if (url == null) {
      _showSnack(kyc.instantError ?? 'Could not start Aadhaar verification.', isError: true);
      return;
    }

    final uri = Uri.tryParse(url);
    final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      _showSnack('Could not open the DigiLocker page. Please try again.', isError: true);
      return;
    }

    setState(() => _digilockerOpened = true);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(_kPollInterval, (_) async {
      _pollCount++;
      if (_pollCount > _kMaxPolls) {
        _pollTimer?.cancel();
        return;
      }
      if (!mounted) return;
      final kyc = context.read<KycFlowProvider>();
      final verified = await kyc.checkAadhaarStatus(silent: true);
      if (!mounted) return;
      if (verified) {
        _pollTimer?.cancel();
        _showSnack('Aadhaar Verified Successfully');
      }
    });
  }

  Future<void> _checkNow() async {
    final kyc = context.read<KycFlowProvider>();
    final verified = await kyc.checkAadhaarStatus();
    if (!mounted) return;
    if (verified) {
      _pollTimer?.cancel();
      _showSnack('Aadhaar Verified Successfully');
    } else if (kyc.instantError != null) {
      _showSnack(kyc.instantError!, isError: true);
    } else {
      _showSnack('Not verified yet. Complete the DigiLocker steps, then check again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycFlowProvider>();
    final s = kyc.instantStatus;

    if (!kyc.instantStatusLoaded) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'KYC Verification'),
        body: const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'KYC Verification'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _ProgressHeader(panDone: s.isPanVerified, aadhaarDone: s.isAadhaarVerified),
            const SizedBox(height: 24),
            _PanSection(
              formKey: _panFormKey,
              panController: _panController,
              nameController: _nameController,
              dobController: _dobController,
              onPickDob: _pickDob,
              onVerify: _verifyPan,
              isLoading: kyc.isPanVerifying,
              verified: s.isPanVerified,
              panName: s.panName,
              panNumber: s.panNumber,
            ),
            if (s.isPanVerified) ...[
              const SizedBox(height: 24),
              _AadhaarSection(
                verified: s.isAadhaarVerified,
                started: _digilockerOpened || s.aadhaarReferenceKnown,
                isStarting: kyc.isAadhaarStarting,
                isChecking: kyc.isAadhaarChecking,
                aadhaarName: s.aadhaarName,
                aadhaarLast4: s.aadhaarLast4,
                onStart: _startAadhaar,
                onCheckNow: _checkNow,
              ),
            ],
            if (s.isFullyVerified) ...[
              const SizedBox(height: 24),
              const _CompletedBanner(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final bool panDone;
  final bool aadhaarDone;

  const _ProgressHeader({required this.panDone, required this.aadhaarDone});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(context),
      child: Column(
        children: [
          _ProgressStep(
            stepNumber: 1,
            title: 'PAN Verification',
            done: panDone,
            isLast: false,
          ),
          _ProgressStep(
            stepNumber: 2,
            title: 'Aadhaar Verification',
            done: aadhaarDone,
            isLast: true,
            enabled: panDone,
          ),
          if (!panDone) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Complete PAN verification to unlock Aadhaar verification.',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final int stepNumber;
  final String title;
  final bool done;
  final bool isLast;
  final bool enabled;

  const _ProgressStep({
    required this.stepNumber,
    required this.title,
    required this.done,
    required this.isLast,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = done
        ? AppColors.green
        : enabled
            ? AppColors.brandOrange
            : colors.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: done ? AppColors.green : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.circle,
                size: done ? 18 : 8,
                color: done ? Colors.white : color,
              ),
            ),
            if (!isLast) Container(width: 2, height: 32, color: done ? AppColors.green.withValues(alpha: 0.4) : colors.border),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 24),
          child: Text(
            'Step $stepNumber\n$title',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: enabled || done ? colors.textPrimary : colors.textMuted,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PanSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController panController;
  final TextEditingController nameController;
  final TextEditingController dobController;
  final VoidCallback onPickDob;
  final VoidCallback onVerify;
  final bool isLoading;
  final bool verified;
  final String panName;
  final String panNumber;

  const _PanSection({
    required this.formKey,
    required this.panController,
    required this.nameController,
    required this.dobController,
    required this.onPickDob,
    required this.onVerify,
    required this.isLoading,
    required this.verified,
    required this.panName,
    required this.panNumber,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (verified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'PAN Verified Successfully',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReadOnlyRow(label: 'PAN Number', value: panNumber),
            _ReadOnlyRow(label: 'Name', value: panName),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAN Verification',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Verified instantly — no photo upload needed.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: panController,
              textCapitalization: TextCapitalization.characters,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'PAN Number',
                hintText: 'ABCDE1234F',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final pan = (v ?? '').toUpperCase().trim();
                if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
                  return 'Enter a valid 10-character PAN';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Full Name (as per PAN)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name as on PAN' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: dobController,
              readOnly: true,
              enabled: !isLoading,
              onTap: isLoading ? null : onPickDob,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Select date of birth' : null,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: isLoading ? null : onVerify,
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify PAN', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AadhaarSection extends StatelessWidget {
  final bool verified;
  final bool started;
  final bool isStarting;
  final bool isChecking;
  final String aadhaarName;
  final String aadhaarLast4;
  final VoidCallback onStart;
  final VoidCallback onCheckNow;

  const _AadhaarSection({
    required this.verified,
    required this.started,
    required this.isStarting,
    required this.isChecking,
    required this.aadhaarName,
    required this.aadhaarLast4,
    required this.onStart,
    required this.onCheckNow,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (verified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Aadhaar Verified Successfully',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReadOnlyRow(label: 'Name', value: aadhaarName),
            if (aadhaarLast4.isNotEmpty) _ReadOnlyRow(label: 'Aadhaar', value: 'XXXX XXXX $aadhaarLast4'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aadhaar Verification',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            started
                ? 'Complete the verification in the DigiLocker page that opened, then come back here.'
                : 'You\'ll be taken to DigiLocker to securely verify your Aadhaar and return here automatically.',
            style: TextStyle(fontSize: 12, color: colors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (started) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for DigiLocker verification…',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isChecking ? null : onCheckNow,
                    child: isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Check Now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isStarting ? null : onStart,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
                    child: const Text('Reopen DigiLocker'),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isStarting ? null : onStart,
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
                icon: isStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.verified_user_outlined, size: 20),
                label: Text(isStarting ? 'Starting…' : 'Verify via DigiLocker', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.brandPrimary, AppColors.green]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'KYC Verification Completed Successfully',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.green)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
