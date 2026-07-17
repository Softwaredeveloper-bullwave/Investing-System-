import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../models/commodity_model.dart';
import '../../models/copy_trading_model.dart';
import '../../models/market_index_model.dart';
import '../../models/goal_plan_model.dart';
import '../../models/investment_model.dart';
import '../../models/investment_doc_model.dart';
import '../../models/market_mood_model.dart';
import '../../models/notification_model.dart';
import '../../models/paper_competition_model.dart';
import '../../models/institutional_flow_model.dart';
import '../../models/portfolio_rebalance_model.dart';
import '../../models/portfolio_health_model.dart';
import '../../models/option_trade_model.dart';
import '../../models/portfolio_model.dart';
import '../../models/referral_model.dart';
import '../../models/stock_model.dart';
import '../../models/trader_note_model.dart';
import '../../models/support_model.dart';
import '../../models/transaction_model.dart';
import '../../models/bank_account_model.dart';
import '../../models/user_model.dart';
import '../../models/wallet_model.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_exception.dart';
import 'json_parsers.dart';
import 'token_storage.dart';

class SendOtpResult {
  const SendOtpResult({this.devOtp, required this.otpMode});

  final String? devOtp;
  final String otpMode;

  bool get isConsoleMode => otpMode == 'console';
}

class BullwaveApi {
  BullwaveApi._();

  static final BullwaveApi instance = BullwaveApi._();
  final _client = ApiClient.instance;

  Future<void> init() => _client.loadToken();

  // ── Auth ──

  Future<SendOtpResult> sendOtp(String phone) async {
    final normalized = _normalizePhone(phone);
    final data = await _client.post(
      '/auth/send-otp/',
      body: {'phone': normalized},
      auth: false,
      timeout: const Duration(seconds: 20),
    ) as Map<String, dynamic>;
    return SendOtpResult(
      devOtp: data['devOtp']?.toString(),
      otpMode: data['otpMode']?.toString() ?? 'console',
    );
  }

  /// DEBUG-only — instant JWT without OTP (backend must have DEBUG=True).
  Future<UserModel> devLogin({String phone = '9999999999'}) async {
    if (kReleaseMode) {
      throw ApiException(404, 'Not available.');
    }
    final data = await _client.post(
      '/auth/dev-login/',
      body: {'phone': phone},
      auth: false,
      timeout: const Duration(seconds: 15),
    ) as Map<String, dynamic>;

    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      throw ApiException(500, 'Dev login failed — invalid server response.');
    }

    await TokenStorage.saveTokens(access: access, refresh: refresh);
    await _client.setAccessToken(access);
    return parseUser(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel> verifyOtp(String phone, String otp) async {
    final normalizedPhone = _normalizePhone(phone);
    final normalizedOtp = otp.replaceAll(RegExp(r'\D'), '');
    final data = await _client.post(
      '/auth/verify-otp/',
      body: {'phone': normalizedPhone, 'otp': normalizedOtp},
      auth: false,
      timeout: const Duration(seconds: 30),
    ) as Map<String, dynamic>;

    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      throw ApiException(500, 'Invalid server response. Please try again.');
    }

    await TokenStorage.saveTokens(access: access, refresh: refresh);
    await _client.setAccessToken(access);
    return parseUser(data['user'] as Map<String, dynamic>);
  }

  static String _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    await _client.setAccessToken(null);
  }

  Future<UserModel> getProfile() async {
    final data = await _client.get('/users/me/') as Map<String, dynamic>;
    return parseUser(data);
  }

  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? city,
    String? bio,
    DateTime? dateOfBirth,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (city != null) body['city'] = city;
    if (bio != null) body['bio'] = bio;
    if (dateOfBirth != null) {
      body['date_of_birth'] = dateOfBirth.toIso8601String().split('T').first;
    }
    final data = await _client.patch('/users/me/', body: body) as Map<String, dynamic>;
    return parseUser(data);
  }

  Future<UserModel> completeProfileSetup({
    required String name,
    String? email,
    String? city,
    String? bio,
    DateTime? dateOfBirth,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{'name': name.trim()};
    if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
    if (city != null && city.trim().isNotEmpty) body['city'] = city.trim();
    if (bio != null && bio.trim().isNotEmpty) body['bio'] = bio.trim();
    if (dateOfBirth != null) {
      body['date_of_birth'] = dateOfBirth.toIso8601String().split('T').first;
    }
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      body['referral_code'] = referralCode.trim().toUpperCase();
    }
    final data =
        await _client.post('/users/me/complete-profile/', body: body) as Map<String, dynamic>;
    return parseUser(data);
  }

  Future<UserModel> uploadAvatar(List<int> bytes, String filename) async {
    final safeName = _avatarFilename(filename);
    final data = await _client.multipart(
      '/users/me/avatar/',
      fields: {},
      files: [
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: safeName,
          contentType: _avatarMediaType(safeName),
        ),
      ],
    ) as Map<String, dynamic>;
    return parseUser(data);
  }

  static String _avatarFilename(String filename) {
    final name = filename.trim();
    if (name.isNotEmpty && name.contains('.')) return name;
    return 'avatar.jpg';
  }

  static MediaType _avatarMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<UserModel> removeAvatar() async {
    final data = await _client.delete('/users/me/avatar/') as Map<String, dynamic>;
    return parseUser(data);
  }

  // ── Home ──

  Future<Map<String, dynamic>> getHome() async {
    return await _client.get('/home/') as Map<String, dynamic>;
  }

  // ── Portfolio ──

  Future<PortfolioModel> getPortfolio() async {
    final data = await _client.get('/portfolio/') as Map<String, dynamic>;
    return parsePortfolio(data);
  }

  Future<List<AllocationItem>> getAllocations() async {
    return parseList(await _client.get('/portfolio/allocations/'), parseAllocation);
  }

  Future<List<MonthlyEarning>> getEarnings() async {
    return parseList(await _client.get('/portfolio/earnings/'), parseMonthlyEarning);
  }

  // ── Investments ──

  Future<List<InvestmentPlanModel>> getInvestmentPlans() async {
    return parseList(await _client.get('/investment/plans/', auth: false), parseInvestmentPlan);
  }

  Future<InvestmentPlanModel> getInvestmentPlan(String planId) async {
    final data = await _client.get('/investment/plans/$planId/', auth: false) as Map<String, dynamic>;
    return parseInvestmentPlan(data);
  }

  Future<List<FaqItem>> getInvestmentFaqs() async {
    final list = parseList(await _client.get('/investment/faqs/', auth: false), (json) {
      return FaqItem(question: json['question'] as String, answer: json['answer'] as String);
    });
    return list;
  }

  Future<InvestmentDetailModel> subscribeInvestment({
    required String planId,
    required double amount,
  }) async {
    final data = await _client.post('/investment/subscribe/', body: {
      'plan_id': planId,
      'amount': amount,
    }) as Map<String, dynamic>;
    return parseInvestmentDetail(data);
  }

  Future<List<InvestmentDetailModel>> getMyInvestments() async {
    return parseList(await _client.get('/investment/my-investments/'), parseInvestmentDetail);
  }

  // ── Wallet ──

  Future<WalletModel> getWallet() async {
    final data = await _client.get('/wallet/') as Map<String, dynamic>;
    return parseWallet(data);
  }

  Future<List<WalletTransaction>> getWalletTransactions() async {
    return parseList(await _client.get('/wallet/transactions/'), parseWalletTransaction);
  }

  Future<void> deposit(double amount) async {
    await _client.post('/wallet/deposit/', body: {'amount': amount});
  }

  Future<void> withdraw(double amount) async {
    await _client.post('/wallet/withdraw/', body: {'amount': amount});
  }

  // ── Transactions ──

  Future<List<TransactionModel>> getTransactions({String? type}) async {
    return parseList(
      await _client.get('/transactions/', query: type != null ? {'type': type} : null),
      parseTransaction,
    );
  }

  // ── Bank & KYC ──

  Future<BankAccountModel?> getBankAccount() async {
    try {
      final data = await _client.get('/bank/') as Map<String, dynamic>;
      return BankAccountModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBankAccount({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifsc,
    required String panNumber,
  }) async {
    await _client.post('/bank/', body: {
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc': ifsc,
      'pan_number': panNumber,
    });
  }

  Future<BankVerificationResponse> verifyBankAccount() async {
    final data =
        await _client.post('/bank/verify/') as Map<String, dynamic>;
    return BankVerificationResponse.fromJson(data);
  }

  Future<void> uploadKycDocument(String documentType) async {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    await _client.multipart(
      '/kyc/documents/',
      fields: {'document_type': documentType},
      files: [
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '$documentType.jpg',
        ),
      ],
    );
  }

  Future<void> submitKyc() async {
    await _client.post('/kyc/submit/');
  }

  Future<List<String>> getKycUploadedDocuments() async {
    final list = await _client.get('/kyc/documents/') as List<dynamic>;
    return list
        .map((e) => (e as Map<String, dynamic>)['documentType'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ── Notifications ──

  Future<List<NotificationModel>> getNotifications() async {
    return parseList(await _client.get('/notifications/'), parseNotification);
  }

  Future<PortfolioRebalanceModel> getPortfolioRebalance() async {
    final data = await _client.get('/portfolio/rebalance/') as Map<String, dynamic>;
    return PortfolioRebalanceModel.fromJson(data);
  }

  Future<PortfolioRebalanceModel> runPortfolioRebalanceCheck() async {
    final data = await _client.post('/portfolio/rebalance/check/') as Map<String, dynamic>;
    return PortfolioRebalanceModel.fromJson(data);
  }

  Future<PortfolioHealthModel> getPortfolioHealth() async {
    final data = await _client.get('/portfolio/health/') as Map<String, dynamic>;
    return PortfolioHealthModel.fromJson(data);
  }

  Future<List<NewsAlertModel>> getNewsAlerts() async {
    return parseList(await _client.get('/news-alerts/'), NewsAlertModel.fromJson);
  }

  Future<NewsAlertModel> createNewsAlert(String keyword) async {
    final data = await _client.post('/news-alerts/', body: {
      'keyword': keyword,
    }) as Map<String, dynamic>;
    return NewsAlertModel.fromJson(data);
  }

  Future<NewsAlertModel> updateNewsAlert(String id, {required bool isActive}) async {
    final data = await _client.patch('/news-alerts/$id/', body: {
      'is_active': isActive,
    }) as Map<String, dynamic>;
    return NewsAlertModel.fromJson(data);
  }

  Future<void> deleteNewsAlert(String id) async {
    await _client.delete('/news-alerts/$id/');
  }

  Future<void> markNotificationRead(String id) async {
    await _client.patch('/notifications/$id/read/');
  }

  Future<void> markAllNotificationsRead() async {
    await _client.post('/notifications/mark-all-read/');
  }

  // ── Support & Referrals ──

  Future<List<SupportFaq>> getSupportFaqs() async {
    return parseList(await _client.get('/support/faqs/', auth: false), parseSupportFaq);
  }

  Future<List<SupportTicketModel>> getSupportTickets() async {
    return parseList(await _client.get('/support/tickets/'), parseSupportTicket);
  }

  Future<void> createSupportTicket({required String subject, String message = ''}) async {
    await _client.post('/support/tickets/', body: {
      'subject': subject,
      'message': message,
    });
  }

  Future<ReferralModel> getReferrals() async {
    final data = await _client.get('/referrals/') as Map<String, dynamic>;
    return parseReferral(data);
  }

  Future<ApplyReferralResult> applyReferralCode(String code) async {
    final data = await _client.post('/referrals/apply/', body: {'code': code.trim()})
        as Map<String, dynamic>;
    return ApplyReferralResult(
      success: data['success'] as bool? ?? true,
      message: data['message'] as String? ?? 'Referral code applied.',
      rewardCreditedToFriend: data['rewardCreditedToFriend'] as bool? ?? false,
    );
  }

  // ── Stocks ──

  Future<List<StockModel>> searchStocks({String query = '', bool live = false}) async {
    return parseList(
      await _client.get(
        '/stocks/search/',
        query: {'q': query, 'exchange': 'NSE', 'live': live ? '1' : '0'},
      ),
      parseStock,
    );
  }

  Future<({List<StockModel> stocks, List<MarketIndexModel> indices, String updatedAt, String provider})> getLiveMarket({bool fast = true}) async {
    final data = await _client.get(
      '/market/live/',
      query: fast ? {'fast': '1'} : {'fast': '0', 'refresh': '1'},
    ) as Map<String, dynamic>;
    return (
      stocks: parseList(data['stocks'], parseStock),
      indices: parseList(data['indices'], parseMarketIndex),
      updatedAt: data['updatedAt'] as String? ?? '',
      provider: data['provider'] as String? ?? 'live',
    );
  }

  Future<Map<String, dynamic>> getTradingViewConfig() async {
    return await _client.get('/market/tradingview/config/') as Map<String, dynamic>;
  }

  Future<({List<CommodityModel> commodities, String updatedAt, String provider})> getCommodities() async {
    final data = await _client.get('/market/commodities/') as Map<String, dynamic>;
    return (
      commodities: parseList(data['commodities'], parseCommodity),
      updatedAt: data['updatedAt'] as String? ?? '',
      provider: data['provider'] as String? ?? 'yahoo',
    );
  }

  Future<CommodityModel> getCommodityDetail(String commodityId) async {
    final data =
        await _client.get('/market/commodities/$commodityId/') as Map<String, dynamic>;
    return parseCommodity(data);
  }

  Future<List<CommodityHoldingModel>> getCommodityHoldings() async {
    final data = await _client.get('/market/commodities/holdings/') as Map<String, dynamic>;
    return parseList(data['holdings'], parseCommodityHolding);
  }

  Future<List<CommodityTradeModel>> getCommodityTrades() async {
    final data = await _client.get('/market/commodities/orders/') as Map<String, dynamic>;
    return parseList(data['trades'], parseCommodityTrade);
  }

  Future<CommodityTradeModel> placeCommodityOrder({
    required String commodityId,
    required String side,
    required int quantity,
  }) async {
    final data = await _client.post('/market/commodities/orders/', body: {
      'commodity_id': commodityId,
      'side': side.toUpperCase(),
      'quantity': quantity,
    }) as Map<String, dynamic>;
    return parseCommodityTrade(data);
  }

  Future<OptionChainResponse> getCommodityOptionChain(
    String commodityId, {
    String? expiry,
    bool fast = false,
  }) async {
    final data = await _client.get(
      '/market/commodities/$commodityId/options/',
      query: {
        'expiry': ?expiry,
        if (fast) 'fast': '1',
      },
      timeout: const Duration(seconds: 45),
    ) as Map<String, dynamic>;
    return OptionChainResponse(
      symbol: data['symbol'] as String? ?? commodityId,
      underlyingValue: _parseDouble(data['underlyingValue']),
      expiryDates: (data['expiryDates'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      selectedExpiry: data['selectedExpiry'] as String? ?? '',
      contracts: parseList(data['contracts'], parseOptionContract),
    );
  }

  Future<StockModel> getStockQuote(String symbol) async {
    final data =
        await _client.get('/stocks/$symbol/quote/') as Map<String, dynamic>;
    return parseStock(data);
  }

  Future<List<CandleModel>> getCandles(
    String symbol, {
    String interval = '1d',
    bool fast = false,
  }) async {
    return parseList(
      await _client.get(
        '/stocks/$symbol/candles/',
        query: {
          'interval': interval,
          if (fast) 'fast': '1',
        },
        timeout: const Duration(seconds: 60),
      ),
      parseCandle,
    );
  }

  Future<List<StockModel>> getWatchlist() async {
    return parseList(await _client.get('/watchlist/'), parseStock);
  }

  Future<StockModel?> addToWatchlist(String symbol) async {
    final data = await _client.post('/watchlist/$symbol/');
    if (data is Map<String, dynamic>) {
      return parseStock(data);
    }
    return null;
  }

  Future<void> removeFromWatchlist(String symbol) async {
    await _client.delete('/watchlist/$symbol/');
  }

  Future<List<StockHoldingModel>> getStockHoldings() async {
    return parseList(await _client.get('/portfolio/holdings/'), parseStockHolding);
  }

  Future<Map<String, dynamic>> getPortfolioOverview({bool refreshQuotes = false}) async {
    return await _client.get(
      '/portfolio/overview/',
      query: {'refresh': refreshQuotes ? '1' : '0'},
      timeout: refreshQuotes ? const Duration(seconds: 90) : const Duration(seconds: 25),
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPortfolioAnalytics() async {
    return await _client.get('/portfolio/analytics/') as Map<String, dynamic>;
  }

  Future<List<StockNewsModel>> getStockNews({String? symbol}) async {
    return parseList(
      await _client.get('/news/', query: symbol != null ? {'symbol': symbol} : null),
      parseStockNews,
    );
  }

  Future<PriceAlertModel> updatePriceAlert(String id, {required bool isActive}) async {
    final data = await _client.patch('/alerts/$id/', body: {
      'is_active': isActive,
    }) as Map<String, dynamic>;
    return parsePriceAlert(data);
  }

  Future<List<PriceAlertModel>> getPriceAlerts() async {
    return parseList(await _client.get('/alerts/'), parsePriceAlert);
  }

  Future<PriceAlertModel> createPriceAlert({
    required String symbol,
    required double targetPrice,
    required String condition,
  }) async {
    final data = await _client.post('/alerts/', body: {
      'symbol': symbol,
      'target_price': targetPrice,
      'condition': condition,
    }) as Map<String, dynamic>;
    return parsePriceAlert(data);
  }

  Future<List<TraderNoteModel>> getTraderNotes({
    String? category,
    String? search,
    bool pinnedOnly = false,
  }) async {
    final query = <String, String>{};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (pinnedOnly) query['pinned'] = 'true';
    final path = query.isEmpty ? '/notes/' : '/notes/?${_encodeQuery(query)}';
    return parseList(await _client.get(path), parseTraderNote);
  }

  Future<TraderNoteModel> createTraderNote({
    required String title,
    required String body,
    String symbol = '',
    String category = 'general',
    bool isPinned = false,
  }) async {
    final data = await _client.post('/notes/', body: {
      'title': title,
      'body': body,
      'symbol': symbol,
      'category': category,
      'is_pinned': isPinned,
    }) as Map<String, dynamic>;
    return parseTraderNote(data);
  }

  Future<TraderNoteModel> updateTraderNote(
    String id, {
    String? title,
    String? body,
    String? symbol,
    String? category,
    bool? isPinned,
  }) async {
    final bodyMap = <String, dynamic>{};
    if (title != null) bodyMap['title'] = title;
    if (body != null) bodyMap['body'] = body;
    if (symbol != null) bodyMap['symbol'] = symbol;
    if (category != null) bodyMap['category'] = category;
    if (isPinned != null) bodyMap['is_pinned'] = isPinned;
    final data = await _client.patch('/notes/$id/', body: bodyMap) as Map<String, dynamic>;
    return parseTraderNote(data);
  }

  Future<void> deleteTraderNote(String id) async {
    await _client.delete('/notes/$id/');
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  Future<List<SipPlanModel>> getSipPlans() async {
    return parseList(await _client.get('/sip/'), parseSipPlan);
  }

  Future<SipPlanModel> createSip({
    required String symbol,
    required double monthlyAmount,
    int totalInstallments = 12,
  }) async {
    final data = await _client.post('/sip/', body: {
      'symbol': symbol,
      'monthly_amount': monthlyAmount,
      'total_installments': totalInstallments,
    }) as Map<String, dynamic>;
    return parseSipPlan(data);
  }

  Future<OptionChainResponse> getOptionChain(String symbol, {String? expiry, bool fast = false}) async {
    final data = await _client.get(
      '/options/$symbol/chain/',
      query: {
        'expiry': ?expiry,
        if (fast) 'fast': '1',
      },
      timeout: const Duration(seconds: 45),
    ) as Map<String, dynamic>;
    return OptionChainResponse(
      symbol: data['symbol'] as String? ?? symbol,
      underlyingValue: _parseDouble(data['underlyingValue']),
      expiryDates: (data['expiryDates'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      selectedExpiry: data['selectedExpiry'] as String? ?? '',
      contracts: parseList(data['contracts'], parseOptionContract),
    );
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  Future<List<PaperTradeModel>> getPaperTrades() async {
    return parseList(await _client.get('/paper-trading/orders/'), parsePaperTrade);
  }

  Future<PaperTradeModel> placePaperTrade({
    required String symbol,
    required String side,
    required int quantity,
  }) async {
    final data = await _client.post('/paper-trading/orders/', body: {
      'symbol': symbol,
      'side': side,
      'quantity': quantity,
    }) as Map<String, dynamic>;
    return parsePaperTrade(data);
  }

  Future<List<OptionHoldingModel>> getOptionHoldings({String? assetClass}) async {
    final data = await _client.get(
      '/options/holdings/',
      query: {'asset_class': ?assetClass},
    ) as Map<String, dynamic>;
    return parseList(data['holdings'], parseOptionHolding);
  }

  Future<OptionTradeModel> placeOptionOrder({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String side,
    required int quantity,
    required double premium,
    required String assetClass,
  }) async {
    final data = await _client.post('/options/orders/', body: {
      'underlying': underlying,
      'strike': strike,
      'option_type': optionType,
      'expiry': expiry.toIso8601String().substring(0, 10),
      'side': side,
      'quantity': quantity,
      'premium': premium,
      'asset_class': assetClass,
    }) as Map<String, dynamic>;
    return parseOptionTrade(data);
  }

  Future<({List<ScreenerStockModel> results, List<String> sectors})> getScreener({
    String? sector,
    String sort = 'market_cap',
  }) async {
    final data = await _client.get(
      '/screener/',
      query: {
        if (sector != null && sector != 'All') 'sector': sector,
        'sort': sort,
      },
    ) as Map<String, dynamic>;
    final results = parseList(data['results'], parseScreenerStock);
    final sectors = (data['sectors'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return (results: results, sectors: sectors);
  }

  Future<List<DividendModel>> getDividends({bool sync = true}) async {
    return parseList(
      await _client.get('/dividends/', query: {if (!sync) 'sync': 'false'}),
      parseDividend,
    );
  }

  Future<List<IpoEventModel>> getIpoCalendar({String? status, int? limit}) async {
    final data = await _client.get(
      '/ipo/calendar/',
      query: {
        'status': ?status,
        if (limit != null) 'limit': '$limit',
      },
    ) as Map<String, dynamic>;
    return parseList(data['events'], parseIpoEvent);
  }

  Future<List<IpoHoldingModel>> getIpoHoldings() async {
    final data = await _client.get('/ipo/holdings/') as Map<String, dynamic>;
    return parseList(data['holdings'], parseIpoHolding);
  }

  Future<List<IpoTradeModel>> getIpoTrades() async {
    final data = await _client.get('/ipo/orders/') as Map<String, dynamic>;
    return parseList(data['trades'], parseIpoTrade);
  }

  Future<IpoTradeModel> placeIpoOrder({
    required String ipoId,
    required String side,
    int lots = 1,
  }) async {
    final data = await _client.post(
      '/ipo/orders/',
      body: {
        'ipo_id': ipoId,
        'side': side,
        'lots': lots,
      },
    ) as Map<String, dynamic>;
    return parseIpoTrade(data);
  }

  Future<String> sendAiMessage(String message, {String symbol = ''}) async {
    final data = await _client.post(
      '/ai/stock-assistant/',
      body: {
        'message': message,
        'symbol': symbol,
      },
      timeout: const Duration(seconds: 120),
    ) as Map<String, dynamic>;
    return data['content'] as String? ?? '';
  }

  Future<List<AiMessageModel>> getAiHistory() async {
    return parseList(await _client.get('/ai/history/'), parseAiMessage);
  }

  Future<void> clearAiHistory() async {
    await _client.delete('/ai/history/');
  }

  Future<List<String>> getAiSuggestions() async {
    final data = await _client.get('/ai/suggestions/') as Map<String, dynamic>;
    return (data['suggestions'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
  }

  Future<Map<String, dynamic>> getAiVoiceStatus() async {
    return await _client.get('/ai/voice/status/') as Map<String, dynamic>;
  }

  Future<MarketMoodModel> getMarketMood({bool withAi = true}) async {
    final data = await _client.get(
      '/ai/market-mood/',
      query: {'ai': withAi ? '1' : '0'},
    ) as Map<String, dynamic>;
    return MarketMoodModel.fromJson(data);
  }

  Future<List<int>> synthesizeAiSpeech(String text) async {
    return _client.postBytes(
      '/ai/tts/',
      body: {'text': text},
      timeout: const Duration(seconds: 90),
    );
  }

  Future<String> transcribeAiSpeech(List<int> audioBytes, {String filename = 'speech.m4a'}) async {
    final data = await _client.multipart(
      '/ai/stt/',
      fields: const {},
      files: [
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
          contentType: MediaType('audio', 'mp4'),
        ),
      ],
      timeout: const Duration(seconds: 90),
    ) as Map<String, dynamic>;
    return (data['text'] as String? ?? '').trim();
  }

  Future<({List<GoalTemplateModel> templates, List<GoalReturnTierModel> returnTiers})> getGoalTemplates() async {
    final data = await _client.get('/goals/templates/');
    if (data is List) {
      return (
        templates: parseList(data, parseGoalTemplate),
        returnTiers: GoalReturnTiersDefaults.tiers,
      );
    }
    final map = data as Map<String, dynamic>;
    final tiersRaw = map['returnTiers'] ?? map['return_tiers'];
    final tiers = tiersRaw is List && tiersRaw.isNotEmpty
        ? parseList(tiersRaw, parseGoalReturnTier)
        : GoalReturnTiersDefaults.tiers;
    return (
      templates: parseList(map['templates'], parseGoalTemplate),
      returnTiers: tiers,
    );
  }

  Future<List<UserGoalPlanModel>> getGoalPlans() async {
    final data = await _client.get('/goals/') as Map<String, dynamic>;
    return parseList(data['goals'], parseUserGoalPlan);
  }

  Future<UserGoalPlanModel> createGoalPlan({
    required String category,
    required String title,
    required double targetAmount,
    required double monthlyContribution,
    required int durationMonths,
    bool payFirstInstallment = true,
  }) async {
    final data = await _client.post(
      '/goals/',
      body: {
        'category': category,
        'title': title,
        'target_amount': targetAmount,
        'monthly_contribution': monthlyContribution,
        'duration_months': durationMonths,
        'pay_first_installment': payFirstInstallment,
      },
    ) as Map<String, dynamic>;
    return parseUserGoalPlan(data);
  }

  Future<UserGoalPlanModel> contributeToGoal(String goalId, {double? amount}) async {
    final data = await _client.post(
      '/goals/$goalId/contribute/',
      body: {'amount': ?amount},
    ) as Map<String, dynamic>;
    return parseUserGoalPlan(data);
  }

  Future<UserGoalPlanModel> withdrawFromGoal(String goalId, {double? amount}) async {
    final data = await _client.post(
      '/goals/$goalId/withdraw/',
      body: {'amount': ?amount},
    ) as Map<String, dynamic>;
    return parseUserGoalPlan(data);
  }

  Future<GoalRemindersModel> getGoalReminders() async {
    return parseGoalReminders(await _client.get('/goals/reminders/') as Map<String, dynamic>);
  }

  Future<EducationCatalogModel> getEducationCatalog() async {
    final data = await _client.get('/education/catalog/') as Map<String, dynamic>;
    return parseEducationCatalog(data);
  }

  Future<InvestmentDocQuiz> getEducationQuiz(String quizSlug) async {
    final data =
        await _client.get('/education/quizzes/$quizSlug/') as Map<String, dynamic>;
    return parseEducationQuiz(data);
  }

  Future<List<CopyTraderModel>> getCopyTraders({String? risk, String? q}) async {
    final data = await _client.get(
      '/copy-trading/traders/',
      query: {
        if (risk != null && risk.isNotEmpty) 'risk': risk,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    ) as Map<String, dynamic>;
    return parseList(data['traders'], parseCopyTrader);
  }

  Future<CopyTraderModel> getCopyTrader(String traderId) async {
    final data =
        await _client.get('/copy-trading/traders/$traderId/') as Map<String, dynamic>;
    return parseCopyTrader(data);
  }

  Future<List<CopySubscriptionModel>> getCopySubscriptions() async {
    final data =
        await _client.get('/copy-trading/subscriptions/') as Map<String, dynamic>;
    return parseList(data['subscriptions'], parseCopySubscription);
  }

  Future<CopySubscriptionModel> startCopyTrading({
    required String traderId,
    required double allocationInr,
    double copyRatio = 1,
    bool autoCopy = true,
  }) async {
    final data = await _client.post(
      '/copy-trading/subscriptions/',
      body: {
        'trader_id': traderId,
        'allocation_inr': allocationInr,
        'copy_ratio': copyRatio,
        'auto_copy': autoCopy,
      },
    ) as Map<String, dynamic>;
    return parseCopySubscription(data);
  }

  Future<CopySubscriptionModel> updateCopySubscription(
    String subscriptionId, {
    String? status,
    double? allocationInr,
    bool? autoCopy,
  }) async {
    final data = await _client.patch(
      '/copy-trading/subscriptions/$subscriptionId/',
      body: {
        'status': ?status,
        'allocation_inr': ?allocationInr,
        'auto_copy': ?autoCopy,
      },
    ) as Map<String, dynamic>;
    return parseCopySubscription(data);
  }

  Future<void> stopCopySubscription(String subscriptionId) async {
    await _client.delete('/copy-trading/subscriptions/$subscriptionId/');
  }

  Future<PaperRiskMeterModel> getPaperRiskMeter() async {
    final data =
        await _client.get('/paper-trading/risk-meter/') as Map<String, dynamic>;
    return PaperRiskMeterModel.fromJson(data);
  }

  Future<PaperRiskMeterModel> getMarketRiskMeter() async {
    final data =
        await _client.get('/portfolio/risk-meter/') as Map<String, dynamic>;
    return PaperRiskMeterModel.fromJson(data);
  }

  Future<BlockDealsResponse> getBlockDeals({
    String? dealType,
    String? side,
    String? q,
  }) async {
    final data = await _client.get(
      '/market/block-deals/',
      query: {
        if (dealType != null && dealType.isNotEmpty) 'deal_type': dealType,
        if (side != null && side.isNotEmpty) 'side': side,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    ) as Map<String, dynamic>;
    return BlockDealsResponse(
      deals: parseList(data['deals'], (j) => BlockDealModel.fromJson(j)),
      summary: BlockDealSummary.fromJson(data['summary'] as Map<String, dynamic>?),
    );
  }

  Future<DarkPoolResponse> getDarkPoolPrints({String? bias, String? q}) async {
    final data = await _client.get(
      '/market/dark-pool/',
      query: {
        if (bias != null && bias.isNotEmpty) 'bias': bias,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    ) as Map<String, dynamic>;
    return DarkPoolResponse(
      prints: parseList(data['prints'], (j) => DarkPoolPrintModel.fromJson(j)),
      summary: DarkPoolSummary.fromJson(data['summary'] as Map<String, dynamic>?),
    );
  }

  Future<List<PaperCompetitionModel>> getPaperCompetitions() async {
    final data =
        await _client.get('/paper-trading/competitions/') as Map<String, dynamic>;
    return parseList(data['competitions'], (j) => PaperCompetitionModel.fromJson(j));
  }

  Future<PaperCompetitionModel> createPaperCompetition({
    String name = '',
    double startingBalance = 100000,
    int durationDays = 7,
  }) async {
    final data = await _client.post(
      '/paper-trading/competitions/',
      body: {
        'action': 'create',
        'name': name,
        'starting_balance': startingBalance,
        'duration_days': durationDays,
      },
    ) as Map<String, dynamic>;
    return PaperCompetitionModel.fromJson(data);
  }

  Future<PaperCompetitionModel> joinPaperCompetition(String inviteCode) async {
    final data = await _client.post(
      '/paper-trading/competitions/',
      body: {
        'action': 'join',
        'invite_code': inviteCode,
      },
    ) as Map<String, dynamic>;
    return PaperCompetitionModel.fromJson(data);
  }

  Future<PaperCompetitionModel> getPaperCompetition(String id) async {
    final data = await _client.get('/paper-trading/competitions/$id/')
        as Map<String, dynamic>;
    return PaperCompetitionModel.fromJson(data);
  }
}
