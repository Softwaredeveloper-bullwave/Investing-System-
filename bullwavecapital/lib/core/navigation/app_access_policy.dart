import '../constants/routes.dart';

/// Central access rules — browse vs trade.
///
/// Users can explore Home, Markets, Portfolio, Wallet, Profile, and Featured Plans
/// without KYC. Trading, deposits, and withdrawals still require verification.
class AppAccessPolicy {
  AppAccessPolicy._();

  static const _browsePaths = {
    AppRoutes.home,
    AppRoutes.invest,
    AppRoutes.portfolio,
    AppRoutes.wallet,
    AppRoutes.profile,
    AppRoutes.featuredPlansList,
    AppRoutes.watchlist,
    AppRoutes.stockNews,
    AppRoutes.stockScreener,
    AppRoutes.ipoCalendar,
    AppRoutes.blockDealTracker,
    AppRoutes.darkPoolTracker,
    AppRoutes.economicCalendar,
    AppRoutes.copyTrading,
    AppRoutes.investmentNotes,
    AppRoutes.investmentCalculator,
    AppRoutes.investmentDocuments,
    AppRoutes.aiAssistant,
    AppRoutes.transactions,
    AppRoutes.commodities,
    AppRoutes.notifications,
    AppRoutes.settings,
    AppRoutes.support,
  };

  static bool isBrowsePath(String path) {
    if (_browsePaths.contains(path)) return true;
    if (path.startsWith(AppRoutes.investmentDocuments)) return true;
    if (path.startsWith('${AppRoutes.featuredPlan}/')) return true;
    if (path.startsWith(AppRoutes.stockDetail)) return true;
    if (path.startsWith(AppRoutes.commodityDetail)) return true;
    if (path.startsWith(AppRoutes.copyTrading)) return true;
    return false;
  }

  static bool requiresKyc(String path) {
    if (isBrowsePath(path)) return false;
    if (path == AppRoutes.completeProfile) return false;

    const tradeAndFunding = {
      AppRoutes.deposit,
      AppRoutes.depositSuccess,
      AppRoutes.withdraw,
      AppRoutes.investmentDetails,
      AppRoutes.paperTrading,
      AppRoutes.optionChain,
      AppRoutes.indexFnoHub,
      AppRoutes.goalPlans,
      AppRoutes.createGoal,
      AppRoutes.goalDetail,
      AppRoutes.priceAlerts,
      AppRoutes.sipTracker,
      AppRoutes.portfolioAnalytics,
      AppRoutes.dividendTracker,
    };

    return tradeAndFunding.contains(path);
  }
}
