import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/referral_model.dart';
import '../provider/referral_support_provider.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _applyCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReferralProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _applyCodeController.dispose();
    super.dispose();
  }

  Future<void> _shareReferral(ReferralModel referral) async {
    await SharePlus.instance.share(
      ShareParams(
        text: referral.shareMessage,
        subject: 'Join BullWave Invest',
      ),
    );
  }

  Future<void> _shareWhatsApp(ReferralModel referral) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(referral.shareMessage)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: referral.shareMessage));
      if (mounted) {
        AppSnackbar.success(context, 'Message copied — paste in WhatsApp');
      }
    }
  }

  Future<void> _applyCode(ReferralProvider provider) async {
    final result = await provider.applyReferralCode(_applyCodeController.text);
    if (!mounted || result == null) {
      if (mounted && provider.error != null) {
        AppSnackbar.error(context, provider.error!);
      }
      return;
    }

    AppSnackbar.success(context, result.message);
    _applyCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final colors = context.appColors;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Refer & Earn'),
      body: RefreshIndicator(
        onRefresh: provider.loadData,
        child: _buildBody(context, provider, colors),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ReferralProvider provider, dynamic colors) {
    if (provider.isLoading && provider.referral == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (provider.error != null && provider.referral == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: colors.textMuted),
          const SizedBox(height: 16),
          Text(
            provider.error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Center(
            child: PrimaryButton(
              label: 'Retry',
              onPressed: provider.loadData,
            ),
          ),
        ],
      );
    }

    final referral = provider.referral!;
    final rewardLabel = CurrencyFormatter.format(referral.rewardPerReferral);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        _HeroBanner(rewardLabel: rewardLabel),
        const SizedBox(height: AppDimensions.paddingLg),
        _HowItWorks(rewardLabel: rewardLabel),
        const SizedBox(height: AppDimensions.paddingLg),
        Text('Your Referral Code', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDimensions.paddingSm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referral.code,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: referral.code));
                    AppSnackbar.success(context, 'Referral code copied!');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingMd),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _shareReferral(referral),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareWhatsApp(referral),
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingSm),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: referral.shareMessage));
            AppSnackbar.success(context, 'Invite message copied!');
          },
          icon: const Icon(Icons.link_rounded, size: 18),
          label: const Text('Copy invite message'),
        ),
        const SizedBox(height: AppDimensions.paddingLg),
        Row(
          children: [
            Expanded(
              child: _ReferralStat(
                label: 'Successful',
                value: '${referral.totalReferrals}',
                icon: Icons.people_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReferralStat(
                label: 'Pending',
                value: '${referral.pendingReferrals}',
                icon: Icons.hourglass_empty_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReferralStat(
                label: 'Earned',
                value: CurrencyFormatter.formatCompact(referral.totalRewards),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        if (!referral.hasAppliedReferral) ...[
          const SizedBox(height: AppDimensions.paddingLg),
          Text('Have a friend\'s code?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Enter their code once. Your friend earns $rewardLabel when you complete your profile.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.paddingSm),
          AppTextField(
            controller: _applyCodeController,
            label: 'Referral Code',
            hint: 'e.g. BW1234AB',
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          PrimaryButton(
            label: 'Apply Code',
            isLoading: provider.isApplying,
            onPressed: provider.isApplying ? null : () => _applyCode(provider),
          ),
        ] else if (referral.appliedReferralCode.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.paddingLg),
          Card(
            color: AppColors.green.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.green),
              title: const Text('Referral code applied'),
              subtitle: Text('You joined with code ${referral.appliedReferralCode}'),
            ),
          ),
        ],
        if (referral.referredFriends.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.paddingLg),
          Text('Friends You Invited', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.paddingSm),
          ...referral.referredFriends.map((friend) => _FriendTile(friend: friend)),
        ],
        const SizedBox(height: AppDimensions.paddingLg),
        Text('Rewards History', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.paddingSm),
        if (referral.rewardsHistory.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard_outlined, size: 40, color: colors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No rewards yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share your code. You earn $rewardLabel when friends complete their profile.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...referral.rewardsHistory.map(
            (reward) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: AppColors.accent),
                ),
                title: Text(reward.friendName),
                subtitle: Text(DateFormatter.display(reward.date)),
                trailing: Text(
                  CurrencyFormatter.format(reward.amount),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String rewardLabel;

  const _HeroBanner({required this.rewardLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Refer & Earn',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Earn $rewardLabel for every friend who joins and completes their profile.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  final String rewardLabel;

  const _HowItWorks({required this.rewardLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it works', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDimensions.paddingSm),
        const _StepTile(
          step: '1',
          title: 'Share your code',
          subtitle: 'Send your unique code via WhatsApp or any app.',
        ),
        const _StepTile(
          step: '2',
          title: 'Friend signs up',
          subtitle: 'They register with mobile OTP and enter your code.',
        ),
        _StepTile(
          step: '3',
          title: 'You get rewarded',
          subtitle: '$rewardLabel is credited to your wallet when they complete their profile.',
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _StepTile({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReferralStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final ReferredFriend friend;

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (friend.status) {
      'rewarded' => ('Rewarded', AppColors.green, Icons.check_circle_outline),
      'completed' => ('Profile done', AppColors.accent, Icons.person_outline),
      _ => ('Pending signup', AppColors.warning, Icons.schedule),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(friend.name),
        subtitle: Text(DateFormatter.display(friend.joinedAt)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
