import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_brand_logo.dart';
import 'premium_auth_ui.dart';

/// Onboarding-style splash — mesh glow, pill tag, bold headline, thin progress.
class SplashAnimation extends StatefulWidget {
  final double progress;

  const SplashAnimation({super.key, this.progress = 0});

  @override
  State<SplashAnimation> createState() => _SplashAnimationState();
}

class _SplashAnimationState extends State<SplashAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthShell(
      glowPrimary: AppColors.brandPrimary,
      glowSecondary: AppColors.brandPink,
      topBar: const PremiumBrandHeader(),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final value = widget.progress > 0 ? widget.progress : _controller.value;
            return PremiumThinProgress(
              value: value,
              label: 'Loading markets',
            );
          },
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            children: [
              const Spacer(flex: 2),
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: const AppBrandWordmark(width: 200),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _contentFade,
                child: Column(
                  children: [
                    const PremiumPillTag(label: 'Today'),
                    const SizedBox(height: 28),
                    Text(
                      'BULLWAVE\nCAPITAL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 36,
                        height: 1.08,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Invest smarter. Trade faster.\nGrow wealth with confidence.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _LiveStatRow(opacity: _contentFade.value),
                  ],
                ),
              ),
              const Spacer(flex: 3),
            ],
          );
        },
      ),
    );
  }
}

class _LiveStatRow extends StatelessWidget {
  final double opacity;

  const _LiveStatRow({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatChip(label: 'NIFTY', value: '+1.24%', color: AppColors.green),
          const SizedBox(width: 10),
          _StatChip(label: 'GOLD', value: '+1.8%', color: AppColors.brandCyan),
          const SizedBox(width: 10),
          _StatChip(label: 'SENSEX', value: '+0.9%', color: AppColors.brandPink),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
