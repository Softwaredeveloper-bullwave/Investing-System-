class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String completeProfile = '/complete-profile';
  static const String bankVerification = '/bank-verification';
  static const String home = '/home';
  static const String invest = '/invest';
  static const String portfolio = '/portfolio';
  static const String wallet = '/wallet';
  static const String profile = '/profile';
  static const String transactions = '/transactions';
  static const String notifications = '/notifications';
  static const String support = '/support';
  static const String kyc = '/kyc';
  static const String kycStatus = '/kyc/status';
  static const String kycSubmit = '/kyc/manual/submit';
  static const String kycPending = '/kyc/manual/pending';
  static const String kycRejected = '/kyc/manual/rejected';
  static const String kycSuccess = '/kyc/success';
  static const String panVerification = '/kyc/pan';
  static const String bankVerificationKyc = '/kyc/bank';
  static const String nameMatch = '/kyc/name-match';
  static const String settings = '/settings';
  static const String editProfile = '/edit-profile';
  static const String referral = '/referral';
  static const String withdraw = '/withdraw';
  static const String deposit = '/deposit';
  static const String depositSuccess = '/deposit/success';
  static const String investmentDetails = '/investment-details';
  static const String featuredPlan = '/invest/plan';
  static const String featuredPlansList = '/invest/plans';
  static const String goalPlans = '/goals';
  static const String createGoal = '/goals/create';
  static const String goalDetail = '/goal-detail';
  static const String bankDetails = '/bank-details';
  static const String privacy = '/privacy';
  static const String terms = '/terms';

  // ── Stocks module ──
  static const String stockDetail = '/stock-detail';
  static const String watchlist = '/watchlist';
  static const String stockNews = '/stock-news';
  static const String stockScreener = '/stock-screener';
  static const String priceAlerts = '/price-alerts';
  static const String economicCalendar = '/economic-calendar';
  static const String sipTracker = '/sip-tracker';
  static const String optionChain = '/option-chain';
  static const String indexFnoHub = '/index-fno';
  static const String fnoVerification = '/fno/verification';
  static const String paperTrading = '/paper-trading';
  static const String paperOrderBook = '/paper-trading/order-book';
  static const String paperJournal = '/paper-trading/journal';
  static const String paperAnalytics = '/paper-trading/analytics';
  static const String paperRiskLimits = '/paper-trading/risk-limits';
  static const String paperOptionChain = '/paper-trading/options';
  static const String paperCommodities = '/paper-trading/commodities';
  static const String paperPortfolio = '/paper-trading/portfolio';
  static const String scalping = '/paper-trading/scalping';
  static const String copyTrading = '/copy-trading';
  static const String copyTraderDetail = '/copy-trading/trader';
  static const String portfolioAnalytics = '/portfolio-analytics';
  static const String dividendTracker = '/dividend-tracker';
  static const String aiAssistant = '/ai-assistant';
  static const String commodities = '/commodities';
  static const String commodityDetail = '/commodity-detail';
  static const String commodityOptionChain = '/commodity-options';
  static const String ipoCalendar = '/ipo-calendar';
  static const String blockDealTracker = '/block-deals';
  static const String darkPoolTracker = '/dark-pool';
  static const String leaderboard = '/leaderboard';
  static const String moodDetector = '/mood-detector';
  static const String investmentNotes = '/investment-notes';
  static const String investmentCalculator = '/investment-calculator';
  static const String investmentDocuments = '/documents';
  static const String documentCategory = '/documents/:categoryId';
  static const String documentArticle = '/documents/:categoryId/:articleId';
  static const String documentQuiz = '/documents/quiz/:quizId';

  static String documentCategoryPath(String categoryId) => '/documents/$categoryId';

  static String documentArticlePath(String categoryId, String articleId) =>
      '/documents/$categoryId/$articleId';

  static String documentQuizPath(String quizId) => '/documents/quiz/$quizId';
}
