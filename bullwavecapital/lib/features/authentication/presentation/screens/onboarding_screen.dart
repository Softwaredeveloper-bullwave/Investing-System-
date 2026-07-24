import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_brand_logo.dart';
import '../../../profile/presentation/provider/app_provider.dart';
import '../widgets/premium_auth_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _fadeController;
  int _currentPage = 0;

  static final _pages = [
    _OnboardingPageData(
      pill: 'Welcome',
      headline: 'A NEW ERA\nOF INVESTING',
      quote:
          'Wealth isn\'t built in a day. It\'s built in the decisions you make — every market open, every goal set, every step forward.',
      glow: AppColors.brandPrimary,
      glowSecondary: AppColors.brandPink,
    ),
    _OnboardingPageData(
      pill: 'Markets',
      headline: 'TRADE WITH\nCLARITY',
      quote:
          'Live NSE & BSE at your fingertips. Charts, watchlists, and F&O chains — one premium terminal built for serious investors.',
      glow: AppColors.brandCyan,
      glowSecondary: AppColors.brandPrimary,
    ),
    _OnboardingPageData(
      pill: 'Growth',
      headline: 'PLANS THAT\nCOMPOUND',
      quote:
          'From curated premium tiers to goal-based SIPs — your portfolio deserves more than average. Up to 4% monthly returns await.',
      glow: AppColors.brandPrimary,
      glowSecondary: AppColors.brandPink,
    ),
    _OnboardingPageData(
      pill: 'Today',
      headline: 'YOUR WEALTH\nAWAITS',
      quote:
          'Secure KYC, encrypted payouts, and AI-powered insights. The market is open — strong investors create strong futures.',
      glow: AppColors.brandPink,
      glowSecondary: AppColors.brandPrimary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await context.read<AppProvider>().completeOnboarding();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _goToPage(int page) async {
    if (page < 0 || page >= _pages.length) return;
    await _fadeController.reverse();
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    if (mounted) {
      setState(() => _currentPage = page);
      _fadeController.forward();
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) _goToPage(_currentPage - 1);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return PremiumAuthShell(
      matchAppTheme: true,
      glowPrimary: page.glow,
      glowSecondary: page.glowSecondary,
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
        child: Row(
          children: [
            const AppBrandWordmark(width: 40, showGlow: false),
            const Spacer(),
            TextButton(
              onPressed: _finishOnboarding,
              child: Text(
                'Skip',
                style: GoogleFonts.inter(
                  color: context.appColors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumLineIndicator(count: _pages.length, current: _currentPage),
          const SizedBox(height: 28),
          PremiumAuthBottomBar(
            backEnabled: _currentPage > 0,
            onBack: _prevPage,
            onNext: _nextPage,
            isLast: isLast,
            onStart: _finishOnboarding,
          ),
        ],
      ),
      child: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _pages.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) {
          final data = _pages[index];
          return FadeTransition(
            opacity: _fadeController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  PremiumPillTag(label: data.pill),
                  const SizedBox(height: 28),
                  PremiumAuthHeadline(text: data.headline),
                  const SizedBox(height: 24),
                  PremiumAuthBody(text: data.quote),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingPageData {
  final String pill;
  final String headline;
  final String quote;
  final Color glow;
  final Color glowSecondary;

  const _OnboardingPageData({
    required this.pill,
    required this.headline,
    required this.quote,
    required this.glow,
    required this.glowSecondary,
  });
}
