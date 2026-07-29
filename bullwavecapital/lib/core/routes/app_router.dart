
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../config/dev_config.dart';
import '../navigation/app_access_policy.dart';

import '../../features/authentication/presentation/provider/auth_provider.dart';

import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';
import '../../features/profile/presentation/provider/app_provider.dart';

import '../../features/authentication/presentation/screens/splash_screen.dart';

import '../../features/authentication/presentation/screens/onboarding_screen.dart';

import '../../features/authentication/presentation/screens/login_screen.dart';

import '../../features/authentication/presentation/screens/otp_screen.dart';

import '../../features/authentication/presentation/screens/email_otp_screen.dart';

import '../../features/authentication/presentation/screens/complete_profile_screen.dart';

import '../../features/home/presentation/screens/home_screen.dart';

import '../../features/investment/presentation/screens/investment_details_screen.dart';
import '../../features/investment/presentation/screens/featured_plan_screen.dart';
import '../../features/investment/presentation/screens/featured_plans_list_screen.dart';
import '../../features/goals/presentation/screens/goal_plans_screen.dart';
import '../../features/goals/presentation/screens/create_goal_screen.dart';
import '../../features/goals/presentation/screens/goal_detail_screen.dart';
import '../../models/investment_model.dart';

import '../../features/stocks/presentation/screens/stock_markets_screen.dart';

import '../../features/stocks/presentation/screens/stock_detail_screen.dart';

import '../../features/stocks/presentation/screens/watchlist_screen.dart';

import '../../features/stocks/presentation/screens/stock_news_screen.dart';

import '../../features/stocks/presentation/screens/stock_screener_screen.dart';

import '../../features/stocks/presentation/screens/price_alerts_screen.dart';
import '../../features/stocks/presentation/screens/economic_calendar_screen.dart';

import '../../features/stocks/presentation/screens/sip_tracker_screen.dart';

import '../../features/stocks/presentation/screens/option_chain_screen.dart';
import '../../features/stocks/presentation/screens/index_fno_hub_screen.dart';

import '../../features/fno/presentation/screens/fno_verification_screen.dart';

import '../../features/stocks/presentation/screens/paper_trading_screen.dart';
import '../../features/stocks/presentation/screens/paper_order_book_screen.dart';
import '../../features/stocks/presentation/screens/paper_journal_screen.dart';
import '../../features/stocks/presentation/screens/paper_analytics_screen.dart';
import '../../features/stocks/presentation/screens/paper_risk_limits_screen.dart';
import '../../features/stocks/presentation/screens/paper_option_chain_screen.dart';
import '../../features/stocks/presentation/screens/paper_commodity_screen.dart';
import '../../features/stocks/presentation/screens/paper_portfolio_screen.dart';
import '../../features/stocks/presentation/screens/scalping_screen.dart';
import '../../features/stocks/presentation/screens/copy_trading_screen.dart';

import '../../features/stocks/presentation/screens/portfolio_analytics_screen.dart';

import '../../features/stocks/presentation/screens/dividend_tracker_screen.dart';

import '../../features/stocks/presentation/screens/ipo_calendar_screen.dart';
import '../../features/stocks/presentation/screens/institutional_flow_screens.dart';
import '../../features/stocks/presentation/screens/leaderboard_screen.dart';
import '../../features/stocks/presentation/screens/mood_detector_screen.dart';
import '../../features/education/presentation/screens/investment_documents_screen.dart';
import '../../features/education/presentation/screens/document_category_screen.dart';
import '../../features/education/presentation/screens/document_reader_screen.dart';
import '../../features/education/presentation/screens/document_quiz_screen.dart';
import '../../features/stocks/presentation/screens/investment_notes_screen.dart';
import '../../features/stocks/presentation/screens/investment_calculator_screen.dart';

import '../../features/stocks/presentation/screens/ai_assistant_screen.dart';
import '../../features/stocks/presentation/screens/commodity_detail_screen.dart';
import '../../features/stocks/presentation/screens/commodity_option_chain_screen.dart';
import '../../features/stocks/presentation/screens/commodity_market_screen.dart';

import '../../features/portfolio/presentation/screens/portfolio_screen.dart';

import '../../features/wallet/presentation/screens/wallet_screen.dart';

import '../../features/profile/presentation/screens/profile_screen.dart';

import '../../features/transactions/presentation/screens/transactions_screen.dart';

import '../../features/notifications/presentation/screens/notifications_screen.dart';

import '../../features/support/presentation/screens/support_screen.dart';

import '../../features/kyc/presentation/screens/kyc_submit_screen.dart';

import '../../features/kyc/presentation/screens/kyc_pending_screen.dart';

import '../../features/kyc/presentation/screens/kyc_rejected_screen.dart';

import '../../features/kyc/presentation/screens/kyc_status_screen.dart';

import '../../features/kyc/presentation/screens/pan_verification_screen.dart';

import '../../features/kyc/presentation/screens/bank_verification_kyc_screen.dart';

import '../../features/kyc/presentation/screens/name_match_screen.dart';

import '../../features/kyc/presentation/screens/kyc_success_screen.dart';

import '../../features/kyc/presentation/screens/bank_verification_screen.dart';

import '../../features/profile/presentation/screens/settings_screen.dart';

import '../../features/profile/presentation/screens/edit_profile_screen.dart';

import '../../features/profile/presentation/screens/referral_screen.dart';

import '../../features/profile/presentation/screens/bank_details_screen.dart';

import '../../features/wallet/presentation/screens/withdraw_screen.dart';

import '../../features/wallet/presentation/screens/deposit_screen.dart';

import '../../features/wallet/presentation/screens/deposit_success_screen.dart';

import '../../features/profile/presentation/screens/privacy_screen.dart';

import '../../features/profile/presentation/screens/terms_screen.dart';

import '../widgets/main_shell.dart';

import '../constants/routes.dart';

import '../constants/dimensions.dart';



class AppRouter {

  AppRouter._();



  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;



  static bool _isPublicAuthRoute(String path) =>

      path == AppRoutes.onboarding ||

      path == AppRoutes.login ||

      path == AppRoutes.otp ||

      path == AppRoutes.emailOtp;



  static bool _isKycOnboardingPath(String path) =>

      path == AppRoutes.kyc ||

      path == AppRoutes.kycStatus ||

      path == AppRoutes.kycSubmit ||

      path == AppRoutes.kycPending ||

      path == AppRoutes.kycRejected ||

      path == AppRoutes.panVerification ||

      path == AppRoutes.bankVerificationKyc ||

      path == AppRoutes.nameMatch ||

      path == AppRoutes.kycSuccess ||

      path == AppRoutes.fnoVerification ||

      path == AppRoutes.bankVerification;



  static bool _requiresKyc(String path) {
    if (_isKycOnboardingPath(path)) return false;
    return AppAccessPolicy.requiresKyc(path);
  }



  /// Primary KYC entry point — the automated Eko PAN → bank → name-match
  /// flow (no photo upload).
  ///
  /// Deliberately does NOT check `kyc.manualStatus` here: a leftover legacy
  /// manual submission stuck as pending/rejected (from before the app moved
  /// to instant Eko verification) used to force users onto a dead-end
  /// "under review" screen with no way back into the new flow, permanently
  /// blocking trading/deposits/withdrawals even though instant verification
  /// was available. `isFullyVerified` still honours an already-*approved*
  /// legacy submission (via `isManualKycVerified`), so nobody who was
  /// previously verified has to redo anything — this only affects users who
  /// were never approved, who should always be able to complete the fast
  /// PAN → bank → name-match path instead of waiting on a stale manual queue.
  static String _kycEntryRoute(KycFlowProvider kyc) {
    final s = kyc.status;
    if (!s.panVerified) return AppRoutes.panVerification;
    if (!s.bankVerified) return AppRoutes.bankVerificationKyc;
    if (!s.nameMatchPassed) return AppRoutes.nameMatch;
    return AppRoutes.home;
  }

  /// Routes that make no sense to sit on once KYC is already verified — the
  /// global redirect below bounces a verified user straight home from these.
  /// Deliberately excludes `AppRoutes.kyc`/`kycStatus`: that's the KYC
  /// section's landing/status page (opened from Profile/Settings), and a
  /// verified user tapping it should see their verified summary, not get
  /// redirected away before the screen even renders.
  static bool _isKycFlowRoute(String path) =>
      path == AppRoutes.kycSubmit ||
      path == AppRoutes.kycPending ||
      path == AppRoutes.kycRejected ||
      path == AppRoutes.panVerification ||
      path == AppRoutes.bankVerificationKyc ||
      path == AppRoutes.nameMatch ||
      path == AppRoutes.kycSuccess;

  static String _postAuthDestination(KycFlowProvider kyc) => AppRoutes.home;



  static GoRouter create(
    AuthProvider auth,
    KycFlowProvider kyc,
    AppProvider app,
  ) =>
      GoRouter(

        navigatorKey: _rootNavigatorKey,

        initialLocation:
            DevConfig.enabled ? AppRoutes.home : AppRoutes.splash,

        refreshListenable: Listenable.merge([auth, kyc, app]),

        redirect: (context, state) {
          if (DevConfig.enabled) return null;

          final path = state.matchedLocation;

          // Splash handles its own routing animation.
          if (path == AppRoutes.splash) return null;

          // Step 2 — onboarding slides (first launch).
          if (!app.hasCompletedOnboarding) {
            if (path == AppRoutes.onboarding) return null;
            return AppRoutes.onboarding;
          }

          // Step 3–4 — phone login + OTP.
          if (!auth.isAuthenticated) {
            // Second factor: phone OTP passed, email step still pending
            // (either entering an email for the first time, or verifying
            // the code just sent to one already on file).
            if (auth.needsEmailVerification || auth.needsEmailSetup) {
              if (path == AppRoutes.emailOtp) return null;
              return AppRoutes.emailOtp;
            }
            if (path == AppRoutes.login || path == AppRoutes.otp) return null;
            return AppRoutes.login;
          }



          if (auth.needsProfileSetup) {

            if (path == AppRoutes.completeProfile) return null;

            return AppRoutes.completeProfile;

          }



          if (_isPublicAuthRoute(path) || path == AppRoutes.completeProfile) {
            return _postAuthDestination(kyc);
          }

          if (kyc.isFullyVerified && _isKycFlowRoute(path)) {
            // Exception: the name-match screen shows a "Verified!" state right
            // as the last step passes, and its own button calls
            // finishKycFlow() (bank_verification_guard.dart) to pop back to
            // whatever triggered the KYC flow. `runNameMatch()` calls
            // notifyListeners() on success, which — via `refreshListenable`
            // above — re-runs this redirect immediately, in the same instant.
            // Without this exception it would win the race and `go(home)`
            // before the user (or finishKycFlow) gets a turn, wiping the
            // pushed stack and losing whatever action the user originally
            // tapped (Buy, deposit, etc.). kycSuccess is exempted for the
            // same reason in case anything ever routes through it directly.
            if (path == AppRoutes.nameMatch || path == AppRoutes.kycSuccess) {
              return null;
            }
            return AppRoutes.home;
          }

          if (!kyc.isFullyVerified && _requiresKyc(path)) {

            return _kycEntryRoute(kyc);

          }



          return null;

        },

        routes: [

          GoRoute(

            path: AppRoutes.splash,

            builder: (context, state) => const SplashScreen(),

          ),

          GoRoute(

            path: AppRoutes.onboarding,

            builder: (context, state) => const OnboardingScreen(),

          ),

          GoRoute(

            path: AppRoutes.login,

            builder: (context, state) => const LoginScreen(),

          ),

          GoRoute(

            path: AppRoutes.otp,

            builder: (context, state) => const OtpScreen(),

          ),

          GoRoute(

            path: AppRoutes.emailOtp,

            builder: (context, state) => const EmailOtpScreen(),

          ),

          GoRoute(

            path: AppRoutes.completeProfile,

            builder: (context, state) => const CompleteProfileScreen(),

          ),

          GoRoute(

            path: AppRoutes.bankVerification,

            builder: (context, state) => const BankVerificationScreen(),

          ),

          ShellRoute(

            navigatorKey: _shellNavigatorKey,

            builder: (context, state, child) => MainShell(child: child),

            routes: [

              GoRoute(

                path: AppRoutes.home,

                pageBuilder: (context, state) => _fadePage(state, const HomeScreen()),

              ),

              GoRoute(

                path: AppRoutes.invest,

                pageBuilder: (context, state) =>

                    _fadePage(state, const StockMarketsScreen()),

              ),

              GoRoute(

                path: AppRoutes.portfolio,

                pageBuilder: (context, state) =>

                    _fadePage(state, const PortfolioScreen()),

              ),

              GoRoute(

                path: AppRoutes.wallet,

                pageBuilder: (context, state) => _fadePage(state, const WalletScreen()),

              ),

              GoRoute(

                path: AppRoutes.profile,

                pageBuilder: (context, state) => _fadePage(state, const ProfileScreen()),

              ),

            ],

          ),

          GoRoute(

            path: AppRoutes.transactions,

            builder: (context, state) => const TransactionsScreen(),

          ),

          GoRoute(

            path: AppRoutes.notifications,

            builder: (context, state) => const NotificationsScreen(),

          ),

          GoRoute(

            path: AppRoutes.support,

            builder: (context, state) => const SupportScreen(),

          ),

          GoRoute(

            path: AppRoutes.kyc,

            builder: (context, state) => const KycStatusScreen(),

          ),

          GoRoute(

            path: AppRoutes.kycStatus,

            builder: (context, state) => const KycStatusScreen(),

          ),

          GoRoute(

            path: AppRoutes.kycSubmit,

            builder: (context, state) => const KycSubmitScreen(),

          ),

          GoRoute(

            path: AppRoutes.kycPending,

            builder: (context, state) => const KycPendingScreen(),

          ),

          GoRoute(

            path: AppRoutes.kycRejected,

            builder: (context, state) => const KycRejectedScreen(),

          ),

          GoRoute(

            path: AppRoutes.panVerification,

            builder: (context, state) => const PanVerificationScreen(),

          ),

          GoRoute(

            path: AppRoutes.bankVerificationKyc,

            builder: (context, state) => const BankVerificationKycScreen(),

          ),

          GoRoute(

            path: AppRoutes.nameMatch,

            builder: (context, state) => const NameMatchScreen(),

          ),

          GoRoute(

            path: AppRoutes.kycSuccess,

            builder: (context, state) => const KycSuccessScreen(),

          ),

          GoRoute(

            path: AppRoutes.settings,

            builder: (context, state) => const SettingsScreen(),

          ),

          GoRoute(

            path: AppRoutes.editProfile,

            builder: (context, state) => const EditProfileScreen(),

          ),

          GoRoute(

            path: AppRoutes.referral,

            builder: (context, state) => const ReferralScreen(),

          ),

          GoRoute(

            path: AppRoutes.withdraw,

            builder: (context, state) => const WithdrawScreen(),

          ),

          GoRoute(

            path: AppRoutes.deposit,

            builder: (context, state) => const DepositScreen(),

          ),

          GoRoute(

            path: AppRoutes.depositSuccess,

            builder: (context, state) => const DepositSuccessScreen(),

          ),

          GoRoute(

            path: AppRoutes.investmentDetails,

            builder: (context, state) => const InvestmentDetailsScreen(),

          ),

          GoRoute(
            path: AppRoutes.featuredPlansList,
            builder: (context, state) => const FeaturedPlansListScreen(),
          ),
          GoRoute(
            path: AppRoutes.goalPlans,
            builder: (context, state) => const GoalPlansScreen(),
          ),
          GoRoute(
            path: AppRoutes.createGoal,
            builder: (context, state) => CreateGoalScreen(
              category: state.uri.queryParameters['category'] ?? 'house',
            ),
          ),
          GoRoute(
            path: AppRoutes.goalDetail,
            builder: (context, state) => GoalDetailScreen(
              goalId: state.uri.queryParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '${AppRoutes.featuredPlan}/:planId',

            builder: (context, state) => FeaturedPlanScreen(
              planId: state.pathParameters['planId'] ?? 'PLAN001',
              initialPlan: state.extra is InvestmentPlanModel ? state.extra as InvestmentPlanModel : null,
            ),

          ),

          GoRoute(

            path: AppRoutes.bankDetails,

            builder: (context, state) => const BankDetailsScreen(),

          ),

          GoRoute(

            path: AppRoutes.privacy,

            builder: (context, state) => const PrivacyScreen(),

          ),

          GoRoute(

            path: AppRoutes.terms,

            builder: (context, state) => const TermsScreen(),

          ),

          GoRoute(

            path: AppRoutes.stockDetail,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {

              final symbol = state.uri.queryParameters['symbol'] ?? 'RELIANCE';

              return StockDetailScreen(symbol: symbol);

            },

          ),

          GoRoute(

            path: AppRoutes.watchlist,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const WatchlistScreen(),

          ),

          GoRoute(

            path: AppRoutes.stockNews,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const StockNewsScreen(),

          ),

          GoRoute(

            path: AppRoutes.stockScreener,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const StockScreenerScreen(),

          ),

          GoRoute(

            path: AppRoutes.priceAlerts,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const PriceAlertsScreen(),

          ),

          GoRoute(

            path: AppRoutes.economicCalendar,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const EconomicCalendarFullScreen(),

          ),

          GoRoute(

            path: AppRoutes.sipTracker,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const SipTrackerScreen(),

          ),

          GoRoute(

            path: AppRoutes.fnoVerification,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const FnoVerificationScreen(),

          ),

          GoRoute(

            path: AppRoutes.optionChain,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {

              final symbol = state.uri.queryParameters['symbol'] ?? 'NIFTY';

              return OptionChainScreen(symbol: symbol);

            },

          ),

          GoRoute(

            path: AppRoutes.indexFnoHub,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {

              final symbol = state.uri.queryParameters['symbol'] ?? 'NIFTY';

              return IndexFnoHubScreen(symbol: symbol);

            },

          ),

          GoRoute(

            path: AppRoutes.paperTrading,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const PaperTradingScreen(),

          ),

          GoRoute(
            path: AppRoutes.paperOrderBook,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaperOrderBookScreen(),
          ),

          GoRoute(
            path: AppRoutes.paperJournal,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaperJournalScreen(),
          ),

          GoRoute(
            path: AppRoutes.paperAnalytics,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaperAnalyticsScreen(),
          ),

          GoRoute(
            path: AppRoutes.paperRiskLimits,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaperRiskLimitsScreen(),
          ),

          GoRoute(
            path: AppRoutes.paperOptionChain,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final symbol = state.uri.queryParameters['symbol'] ?? 'NIFTY';
              return PaperOptionChainScreen(symbol: symbol);
            },
          ),

          GoRoute(
            path: AppRoutes.paperCommodities,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaperCommodityScreen(),
          ),

          GoRoute(
            path: AppRoutes.paperPortfolio,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaperPortfolioScreen(),
          ),

          GoRoute(
            path: AppRoutes.scalping,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final symbol = state.uri.queryParameters['symbol'];
              return ScalpingScreen(initialSymbol: symbol);
            },
          ),

          GoRoute(

            path: AppRoutes.copyTrading,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const CopyTradingScreen(),

          ),

          GoRoute(

            path: AppRoutes.copyTraderDetail,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {
              final id = state.uri.queryParameters['id'] ?? '';
              return CopyTraderDetailScreen(traderId: id);
            },

          ),

          GoRoute(

            path: AppRoutes.portfolioAnalytics,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const PortfolioAnalyticsScreen(),

          ),

          GoRoute(

            path: AppRoutes.dividendTracker,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const DividendTrackerScreen(),

          ),

          GoRoute(

            path: AppRoutes.ipoCalendar,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const IpoCalendarScreen(),

          ),

          GoRoute(

            path: AppRoutes.blockDealTracker,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const BlockDealTrackerScreen(),

          ),

          GoRoute(

            path: AppRoutes.darkPoolTracker,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const DarkPoolTrackerScreen(),

          ),

          GoRoute(

            path: AppRoutes.leaderboard,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const LeaderboardScreen(),

          ),

          GoRoute(

            path: AppRoutes.moodDetector,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const MoodDetectorScreen(),

          ),

          GoRoute(

            path: AppRoutes.investmentNotes,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const InvestmentNotesScreen(
              title: 'Investment Journal',
            ),

          ),

          GoRoute(

            path: AppRoutes.investmentCalculator,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const InvestmentCalculatorScreen(),

          ),

          GoRoute(

            path: AppRoutes.investmentDocuments,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const InvestmentDocumentsScreen(),

          ),

          GoRoute(

            path: AppRoutes.documentQuiz,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => DocumentQuizScreen(
              quizId: state.pathParameters['quizId'] ?? '',
            ),

          ),

          GoRoute(

            path: AppRoutes.documentArticle,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => DocumentReaderScreen(
              categoryId: state.pathParameters['categoryId'] ?? '',
              articleId: state.pathParameters['articleId'] ?? '',
            ),

          ),

          GoRoute(

            path: AppRoutes.documentCategory,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => DocumentCategoryScreen(
              categoryId: state.pathParameters['categoryId'] ?? '',
            ),

          ),

          GoRoute(

            path: AppRoutes.aiAssistant,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {
              final voice = state.uri.queryParameters['voice'];
              final startWithVoice = voice == '1' || voice == 'true';
              return AiAssistantScreen(startWithVoice: startWithVoice);
            },

          ),

          GoRoute(

            path: AppRoutes.commodities,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) => const CommodityMarketScreen(),

          ),

          GoRoute(

            path: AppRoutes.commodityDetail,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {

              final commodityId = state.uri.queryParameters['commodityId'] ?? 'GOLD';

              return CommodityDetailScreen(commodityId: commodityId);

            },

          ),

          GoRoute(

            path: AppRoutes.commodityOptionChain,

            parentNavigatorKey: _rootNavigatorKey,

            builder: (context, state) {

              final commodityId = state.uri.queryParameters['commodityId'] ?? 'GOLD';

              return CommodityOptionChainScreen(commodityId: commodityId);

            },

          ),

        ],

      );



  static CustomTransitionPage _fadePage(GoRouterState state, Widget child) {

    return CustomTransitionPage(

      key: ValueKey('tab-${state.matchedLocation}'),

      transitionDuration: AppDimensions.transitionFast,

      reverseTransitionDuration: AppDimensions.transitionFast,

      child: child,

      transitionsBuilder: (context, animation, secondaryAnimation, child) {

        final slide = Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)

            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return FadeTransition(

          opacity: animation,

          child: SlideTransition(position: slide, child: child),

        );

      },

    );

  }

}


