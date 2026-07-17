import 'package:flutter/material.dart';

import '../../models/commodity_model.dart';
import '../../models/copy_trading_model.dart';
import '../../models/goal_plan_model.dart';
import '../../models/investment_model.dart';
import '../../models/investment_doc_model.dart';
import '../../models/market_index_model.dart';
import '../../models/notification_model.dart';
import '../../models/option_trade_model.dart';
import '../../models/portfolio_model.dart';
import '../../models/referral_model.dart';
import '../../models/stock_model.dart';
import '../../models/trader_note_model.dart';
import '../../models/support_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../models/wallet_model.dart';
import '../utils/formatters.dart';

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) {
    final parsed = int.tryParse(v.trim());
    if (parsed != null) return parsed;
    return double.tryParse(v.trim())?.toInt() ?? 0;
  }
  return 0;
}
DateTime _date(dynamic v) {
  if (v == null) return DateTime.now();
  final s = v.toString().trim();
  if (s.isEmpty) return DateTime.now();
  try {
    if (s.length <= 10) return DateTime.parse(s);
    return DateTime.parse(s);
  } catch (_) {
    return DateTime.now();
  }
}

UserModel parseUser(Map<String, dynamic> json) => UserModel.fromJson(json);

PortfolioModel parsePortfolio(Map<String, dynamic> json) => PortfolioModel(
      totalInvestment: _num(json['totalInvestment']),
      currentValue: _num(json['currentValue']),
      monthlyProfit: _num(json['monthlyProfit']),
      totalProfit: _num(json['totalProfit']),
      growthPercent: _num(json['growthPercent']),
      dayPnl: _num(json['dayPnl']),
      dayPnlPercent: _num(json['dayPnlPercent']),
      holdingsCount: _int(json['holdingsCount']),
      stocksInvested: _num(json['stocksInvested']),
      stocksValue: _num(json['stocksValue']),
      walletBalance: _num(json['walletBalance']),
    );

PortfolioSummaryModel parsePortfolioSummary(Map<String, dynamic> json) =>
    PortfolioSummaryModel(
      totalInvested: _num(json['totalInvested']),
      currentValue: _num(json['currentValue']),
      totalPnl: _num(json['totalPnl']),
      totalPnlPercent: _num(json['totalPnlPercent']),
      dayPnl: _num(json['dayPnl']),
      dayPnlPercent: _num(json['dayPnlPercent']),
      holdingsCount: _int(json['holdingsCount']),
    );

SectorAllocationItem parseSectorAllocation(Map<String, dynamic> json) =>
    SectorAllocationItem(
      label: json['label'] as String? ?? '',
      value: _num(json['value']),
      percentage: _num(json['percentage']),
      colorValue: _int(json['colorValue']),
    );

WalletModel parseWallet(Map<String, dynamic> json) => WalletModel(
      balance: _num(json['balance']),
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      ifsc: json['ifsc'] as String? ?? '',
    );

WalletTransaction parseWalletTransaction(Map<String, dynamic> json) =>
    WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      amount: _num(json['amount']),
      date: _date(json['date']),
      status: json['status'] as String? ?? '',
    );

TransactionModel parseTransaction(Map<String, dynamic> json) {
  TransactionType type;
  switch (json['type'] as String? ?? '') {
    case 'profit':
      type = TransactionType.profit;
      break;
    case 'withdrawal':
      type = TransactionType.withdrawal;
      break;
    default:
      type = TransactionType.investment;
  }

  TransactionStatus status;
  switch (json['status'] as String? ?? '') {
    case 'pending':
      status = TransactionStatus.pending;
      break;
    case 'failed':
      status = TransactionStatus.failed;
      break;
    default:
      status = TransactionStatus.completed;
  }

  return TransactionModel(
    id: json['id']?.toString() ?? '',
    referenceId: json['referenceId'] as String? ?? '',
    type: type,
    status: status,
    amount: _num(json['amount']),
    date: _date(json['date']),
    description: json['description'] as String? ?? '',
  );
}

InvestmentPlanModel parseInvestmentPlan(Map<String, dynamic> json) {
  final monthlyRate = _num(json['monthlyReturnRate']);
  return InvestmentPlanModel(
    id: json['id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    minimumInvestment: _num(json['minimumInvestment']),
    monthlyReturnRate: monthlyRate,
    monthlyReturnMin: json['monthlyReturnMin'] != null ? _num(json['monthlyReturnMin']) : monthlyRate,
    monthlyReturnMax: json['monthlyReturnMax'] != null ? _num(json['monthlyReturnMax']) : monthlyRate,
    annualReturnRate: _num(json['annualReturnRate']),
    description: json['description'] as String? ?? '',
    isFeatured: json['isFeatured'] as bool? ?? false,
  );
}

InvestmentDetailModel parseInvestmentDetail(Map<String, dynamic> json) =>
    InvestmentDetailModel(
      id: json['id']?.toString() ?? '',
      amount: _num(json['amount']),
      date: _date(json['date']),
      monthlyReturn: _num(json['monthlyReturn']),
      status: json['status'] as String? ?? '',
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );

MarketIndexModel parseMarketIndex(Map<String, dynamic> json) => MarketIndexModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
      value: _num(json['value']),
      change: _num(json['change']),
      changePercent: _num(json['changePercent']),
    );

CommodityModel parseCommodity(Map<String, dynamic> json) => CommodityModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      currency: json['currency'] as String? ?? 'USD',
      icon: json['icon'] as String? ?? 'metal',
      ltp: _num(json['ltp']),
      change: _num(json['change']),
      changePercent: _num(json['changePercent']),
      high: _num(json['high']),
      low: _num(json['low']),
      previousClose: _num(json['previousClose']),
      usdInrRate: _num(json['usdInrRate']) > 0 ? _num(json['usdInrRate']) : 83.5,
    );

CommodityHoldingModel parseCommodityHolding(Map<String, dynamic> json) => CommodityHoldingModel(
      commodityId: json['commodityId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      quantity: _int(json['quantity']),
      avgPriceUsd: _num(json['avgPriceUsd']),
      ltpUsd: _num(json['ltpUsd']),
      investedInr: _num(json['investedInr']),
      currentValueInr: _num(json['currentValueInr']),
      pnlInr: _num(json['pnlInr']),
      pnlPercent: _num(json['pnlPercent']),
    );

CommodityTradeModel parseCommodityTrade(Map<String, dynamic> json) => CommodityTradeModel(
      id: json['id']?.toString() ?? '',
      commodityId: json['commodityId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      side: json['side'] as String? ?? '',
      quantity: _int(json['quantity']),
      priceUsd: _num(json['priceUsd']),
      amountInr: _num(json['amountInr']),
      usdInrRate: _num(json['usdInrRate']),
      time: _date(json['time']),
      status: json['status'] as String? ?? '',
      orderValueUsd: _num(json['orderValueUsd']),
      ltpUsd: _num(json['ltpUsd']),
      avgCostUsd: json['avgCostUsd'] != null ? _num(json['avgCostUsd']) : null,
      realizedPnlInr: json['realizedPnlInr'] != null ? _num(json['realizedPnlInr']) : null,
      holdingQty: json['holdingQty'] != null ? _int(json['holdingQty']) : null,
      holdingAvgPriceUsd:
          json['holdingAvgPriceUsd'] != null ? _num(json['holdingAvgPriceUsd']) : null,
    );

OptionHoldingModel parseOptionHolding(Map<String, dynamic> json) => OptionHoldingModel(
      underlying: json['underlying'] as String? ?? '',
      assetClass: json['assetClass'] as String? ?? 'equity_fno',
      strike: _num(json['strike']),
      optionType: json['optionType'] as String? ?? '',
      expiry: _date(json['expiry']),
      contractLabel: json['contractLabel'] as String? ?? '',
      quantity: _int(json['quantity']),
      avgPremium: _num(json['avgPremium']),
      lotSize: _int(json['lotSize']),
    );

OptionTradeModel parseOptionTrade(Map<String, dynamic> json) => OptionTradeModel(
      id: json['id']?.toString() ?? '',
      underlying: json['underlying'] as String? ?? '',
      assetClass: json['assetClass'] as String? ?? 'equity_fno',
      strike: _num(json['strike']),
      optionType: json['optionType'] as String? ?? '',
      expiry: _date(json['expiry']),
      contractLabel: json['contractLabel'] as String? ?? '',
      side: json['side'] as String? ?? '',
      quantity: _int(json['quantity']),
      premium: _num(json['premium']),
      lotSize: _int(json['lotSize']),
      amountInr: _num(json['amountInr']),
      time: _date(json['time']),
      status: json['status'] as String? ?? '',
      avgPremium: json['avgPremium'] != null ? _num(json['avgPremium']) : null,
      realizedPnlInr: json['realizedPnlInr'] != null ? _num(json['realizedPnlInr']) : null,
      holdingQty: json['holdingQty'] != null ? _int(json['holdingQty']) : null,
    );

AllocationItem parseAllocation(Map<String, dynamic> json) => AllocationItem(
      label: json['label'] as String? ?? '',
      percentage: _num(json['percentage']),
      colorValue: _int(json['colorValue']),
    );

MonthlyEarning parseMonthlyEarning(Map<String, dynamic> json) => MonthlyEarning(
      month: json['month'] as String? ?? '',
      amount: _num(json['amount']),
    );

NotificationModel parseNotification(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      date: _date(json['date']),
      isRead: json['isRead'] as bool? ?? false,
      type: json['type'] as String? ?? 'general',
    );

SupportFaq parseSupportFaq(Map<String, dynamic> json) => SupportFaq(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );

SupportTicketModel parseSupportTicket(Map<String, dynamic> json) =>
    SupportTicketModel(
      id: json['id']?.toString() ?? '',
      subject: json['subject'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: _date(json['createdAt']),
    );

ReferralModel parseReferral(Map<String, dynamic> json) => ReferralModel(
      code: json['code'] as String? ?? '',
      totalReferrals: _int(json['totalReferrals']),
      pendingReferrals: _int(json['pendingReferrals']),
      totalRewards: _num(json['totalRewards']),
      rewardPerReferral: _num(json['rewardPerReferral']),
      shareMessage: json['shareMessage'] as String? ?? '',
      hasAppliedReferral: json['hasAppliedReferral'] as bool? ?? false,
      appliedReferralCode: json['appliedReferralCode'] as String? ?? '',
      rewardsHistory: (json['rewardsHistory'] as List<dynamic>? ?? [])
          .map((e) => parseReferralReward(e as Map<String, dynamic>))
          .toList(),
      referredFriends: (json['referredFriends'] as List<dynamic>? ?? [])
          .map((e) => parseReferredFriend(e as Map<String, dynamic>))
          .toList(),
    );

ReferralReward parseReferralReward(Map<String, dynamic> json) => ReferralReward(
      friendName: json['friendName'] as String? ?? '',
      amount: _num(json['amount']),
      date: _date(json['date']),
    );

ReferredFriend parseReferredFriend(Map<String, dynamic> json) => ReferredFriend(
      name: json['name'] as String? ?? '',
      joinedAt: _date(json['joinedAt']),
      status: json['status'] as String? ?? 'pending',
    );

StockModel parseStock(Map<String, dynamic> json) => StockModel(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      exchange: json['exchange'] as String? ?? 'NSE',
      sector: json['sector'] as String? ?? '',
      ltp: _num(json['ltp']),
      change: _num(json['change']),
      changePercent: _num(json['changePercent']),
      open: _num(json['open']),
      high: _num(json['high']),
      low: _num(json['low']),
      previousClose: _num(json['previousClose']),
      volume: _int(json['volume']),
      marketCapCr: _num(json['marketCapCr']),
      pe: _num(json['pe']),
      eps: _num(json['eps']),
      week52High: _num(json['week52High']),
      week52Low: _num(json['week52Low']),
    );

CandleModel parseCandle(Map<String, dynamic> json) => CandleModel(
      time: _date(json['time']),
      open: _num(json['open']),
      high: _num(json['high']),
      low: _num(json['low']),
      close: _num(json['close']),
      volume: _int(json['volume']),
    );

StockHoldingModel parseStockHolding(Map<String, dynamic> json) =>
    StockHoldingModel(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      exchange: json['exchange'] as String? ?? 'NSE',
      quantity: _int(json['quantity']),
      avgPrice: _num(json['avgPrice']),
      ltp: _num(json['ltp']),
      change: _num(json['change']),
      changePercent: _num(json['changePercent']),
      dayPnl: _num(json['dayPnl']),
    );

StockNewsModel parseStockNews(Map<String, dynamic> json) => StockNewsModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      source: json['source'] as String? ?? '',
      publishedAt: _date(json['publishedAt']),
      relatedSymbols: (json['relatedSymbols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String? ?? 'market',
      url: json['url'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );

PriceAlertModel parsePriceAlert(Map<String, dynamic> json) => PriceAlertModel(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      targetPrice: _num(json['targetPrice']),
      condition: json['condition'] as String? ?? 'above',
      isActive: json['isActive'] as bool? ?? true,
    );

SipPlanModel parseSipPlan(Map<String, dynamic> json) => SipPlanModel(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      monthlyAmount: _num(json['monthlyAmount']),
      installmentsDone: _int(json['installmentsDone']),
      totalInstallments: _int(json['totalInstallments']),
      totalInvested: _num(json['totalInvested']),
      currentValue: _num(json['currentValue']),
      nextDate: DateFormatter.parseDateOnly(json['nextDate'] as String? ?? ''),
    );

OptionContractModel parseOptionContract(Map<String, dynamic> json) =>
    OptionContractModel(
      symbol: json['symbol'] as String? ?? '',
      strike: _num(json['strike']),
      type: json['type'] as String? ?? '',
      ltp: _num(json['ltp']),
      change: _num(json['change']),
      oi: _int(json['oi']),
      volume: _int(json['volume']),
      expiry: _date(json['expiry']),
    );

PaperTradeModel parsePaperTrade(Map<String, dynamic> json) => PaperTradeModel(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol'] as String? ?? '',
      stockName: json['stockName'] as String? ?? '',
      side: json['side'] as String? ?? '',
      quantity: _int(json['quantity']),
      price: _num(json['price']),
      time: _date(json['time']),
      status: json['status'] as String? ?? '',
      orderValue: _num(json['orderValue']),
      avgCost: json['avgCost'] != null ? _num(json['avgCost']) : null,
      realizedPnl: json['realizedPnl'] != null ? _num(json['realizedPnl']) : null,
      realizedPnlPercent:
          json['realizedPnlPercent'] != null ? _num(json['realizedPnlPercent']) : null,
      holdingQty: json['holdingQty'] != null ? _int(json['holdingQty']) : null,
      holdingAvgPrice:
          json['holdingAvgPrice'] != null ? _num(json['holdingAvgPrice']) : null,
      unrealizedPnl: json['unrealizedPnl'] != null ? _num(json['unrealizedPnl']) : null,
      ltp: _num(json['ltp']),
    );

DividendModel parseDividend(Map<String, dynamic> json) => DividendModel(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amountPerShare: _num(json['amountPerShare']),
      exDate: DateFormatter.parseDateOnly(json['exDate'] as String? ?? ''),
      paymentDate: DateFormatter.parseDateOnly(json['paymentDate'] as String? ?? ''),
      sharesHeld: _int(json['sharesHeld']),
      status: json['status'] as String? ?? '',
    );

ScreenerStockModel parseScreenerStock(Map<String, dynamic> json) =>
    ScreenerStockModel(
      stock: parseStock(json['stock'] as Map<String, dynamic>),
      roe: _num(json['roe']),
      debtToEquity: _num(json['debtToEquity']),
      revenueGrowth: _num(json['revenueGrowth']),
    );

AiMessageModel parseAiMessage(Map<String, dynamic> json) => AiMessageModel(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      time: _date(json['createdAt'] ?? json['time']),
    );

Color _goalColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF9333EA);
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) {
    return Color(int.parse('FF$h', radix: 16));
  }
  return const Color(0xFF9333EA);
}

GoalTemplateModel parseGoalTemplate(Map<String, dynamic> json) => GoalTemplateModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      icon: json['icon'] as String? ?? 'savings',
      color: _goalColor(json['color'] as String?),
      minTarget: _num(json['minTarget'] ?? json['min_target']),
      suggestedMonthly: _num(json['suggestedMonthly'] ?? json['suggested_monthly']),
      minDurationMonths: (json['minDurationMonths'] ?? json['min_duration_months'] ?? 3) as int,
      maxDurationMonths: (json['maxDurationMonths'] ?? json['max_duration_months'] ?? 24) as int,
    );

GoalReturnTierModel parseGoalReturnTier(Map<String, dynamic> json) => GoalReturnTierModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      minMonthly: _num(json['minMonthly'] ?? json['min_monthly']),
      maxMonthly: json['maxMonthly'] == null && json['max_monthly'] == null
          ? null
          : _num(json['maxMonthly'] ?? json['max_monthly']),
      annualReturnRate: _num(json['annualReturnRate'] ?? json['annual_return_rate']),
      badge: json['badge'] as String? ?? '',
      color: _goalColor(json['color'] as String?),
    );

UserGoalPlanModel parseUserGoalPlan(Map<String, dynamic> json) => UserGoalPlanModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      targetAmount: _num(json['targetAmount'] ?? json['target_amount']),
      monthlyContribution: _num(json['monthlyContribution'] ?? json['monthly_contribution']),
      durationMonths: (json['durationMonths'] ?? json['duration_months'] ?? 0) as int,
      accumulatedAmount: _num(json['accumulatedAmount'] ?? json['accumulated_amount']),
      returnsEarned: _num(json['returnsEarned'] ?? json['returns_earned']),
      annualReturnRate: _num(json['annualReturnRate'] ?? json['annual_return_rate']) == 0
          ? 8
          : _num(json['annualReturnRate'] ?? json['annual_return_rate']),
      projectedMaturityValue: _num(json['projectedMaturityValue'] ?? json['projected_maturity_value']),
      projectedReturns: _num(json['projectedReturns'] ?? json['projected_returns']),
      installmentsDone: (json['installmentsDone'] ?? json['installments_done'] ?? 0) as int,
      totalInstallments: (json['totalInstallments'] ?? json['total_installments'] ?? 0) as int,
      progressPercent: _num(json['progressPercent'] ?? json['progress_percent']),
      nextContributionDate: json['nextContributionDate'] as String? ?? json['next_contribution_date'] as String?,
      targetDate: json['targetDate'] as String? ?? json['target_date'] as String?,
      status: json['status'] as String? ?? 'active',
      referenceId: json['referenceId'] as String? ?? json['reference_id'] as String? ?? '',
      returnTier: json['returnTier'] as String? ?? json['return_tier'] as String? ?? 'starter',
      color: _goalColor(json['color'] as String?),
      canWithdraw: json['canWithdraw'] == true || json['can_withdraw'] == true,
      isDue: json['isDue'] == true || json['is_due'] == true,
    );

GoalRemindersModel parseGoalReminders(Map<String, dynamic> json) => GoalRemindersModel(
      due: parseList(json['due'], parseUserGoalPlan),
      activeCount: (json['activeCount'] ?? json['active_count'] ?? 0) as int,
    );

List<T> parseList<T>(dynamic data, T Function(Map<String, dynamic>) parser) {
  if (data is! List) return [];
  final out = <T>[];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    try {
      out.add(parser(item));
    } catch (_) {}
  }
  return out;
}

IpoEventModel parseIpoEvent(Map<String, dynamic> json) => IpoEventModel(
      id: json['id'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      status: json['status'] as String? ?? 'upcoming',
      openDate: json['openDate'] != null
          ? DateFormatter.parseDateOnly(json['openDate'] as String)
          : null,
      closeDate: json['closeDate'] != null
          ? DateFormatter.parseDateOnly(json['closeDate'] as String)
          : null,
      listingDate: json['listingDate'] != null
          ? DateFormatter.parseDateOnly(json['listingDate'] as String)
          : null,
      priceBandMin: _num(json['priceBandMin']),
      priceBandMax: _num(json['priceBandMax']),
      issueSizeCr: _num(json['issueSizeCr']),
      lotSize: _int(json['lotSize']),
      minInvestment: _num(json['minInvestment']),
      gmpPercent: json['gmpPercent'] != null ? _num(json['gmpPercent']) : null,
      subscriptionTimes: json['subscriptionTimes'] as String?,
      exchange: json['exchange'] as String? ?? 'NSE',
      isFeatured: json['isFeatured'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      listingPrice: _num(json['listingPrice'] ?? json['priceBandMax']),
    );

IpoHoldingModel parseIpoHolding(Map<String, dynamic> json) => IpoHoldingModel(
      ipoId: json['ipoId'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      ipoStatus: json['ipoStatus'] as String? ?? '',
      lots: _int(json['lots']),
      quantity: _int(json['quantity']),
      avgPrice: _num(json['avgPrice']),
      ltp: _num(json['ltp']),
      investedInr: _num(json['investedInr']),
      currentValueInr: _num(json['currentValueInr']),
      pnlInr: _num(json['pnlInr']),
      pnlPercent: _num(json['pnlPercent']),
      canSell: json['canSell'] as bool? ?? false,
    );

IpoTradeModel parseIpoTrade(Map<String, dynamic> json) => IpoTradeModel(
      id: json['id']?.toString() ?? '',
      ipoId: json['ipoId'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      side: json['side'] as String? ?? '',
      lots: _int(json['lots']),
      quantity: _int(json['quantity']),
      price: _num(json['price']),
      amountInr: _num(json['amountInr']),
      time: _date(json['time']),
      status: json['status'] as String? ?? '',
    );

EducationCatalogModel parseEducationCatalog(Map<String, dynamic> json) {
  final categoriesRaw = json['categories'] as List<dynamic>? ?? [];
  return EducationCatalogModel(
    updatedAt: _date(json['updatedAt']),
    categories: categoriesRaw
        .map((e) => InvestmentDocCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

InvestmentDocQuiz parseEducationQuiz(Map<String, dynamic> json) =>
    InvestmentDocQuiz.fromJson(json);

TraderNoteModel parseTraderNote(Map<String, dynamic> json) => TraderNoteModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      category: json['category'] as String? ?? 'general',
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );

CopyTraderTradeModel parseCopyTraderTrade(Map<String, dynamic> json) =>
    CopyTraderTradeModel(
      id: json['id']?.toString() ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      side: json['side'] as String? ?? '',
      quantity: _int(json['quantity']),
      price: _num(json['price']),
      pnlPercent: json['pnlPercent'] != null ? _num(json['pnlPercent']) : null,
      note: json['note'] as String? ?? '',
      executedAt: _date(json['executedAt']),
    );

CopyTraderModel parseCopyTrader(Map<String, dynamic> json) {
  final tags = (json['methodTags'] as List<dynamic>? ?? [])
      .map((e) => e.toString())
      .toList();
  final tradesRaw = json['recentTrades'] as List<dynamic>? ?? [];
  return CopyTraderModel(
    id: json['id']?.toString() ?? '',
    displayName: json['displayName'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    avatarColor: json['avatarColor'] as String? ?? '#10B981',
    bio: json['bio'] as String? ?? '',
    strategyTitle: json['strategyTitle'] as String? ?? '',
    strategySummary: json['strategySummary'] as String? ?? '',
    methodTags: tags,
    riskLevel: json['riskLevel'] as String? ?? 'medium',
    isVerified: json['isVerified'] as bool? ?? true,
    return1m: _num(json['return1m']),
    return3m: _num(json['return3m']),
    return1y: _num(json['return1y']),
    winRate: _num(json['winRate']),
    maxDrawdown: _num(json['maxDrawdown']),
    followersCount: _int(json['followersCount']),
    aumInr: _num(json['aumInr']),
    minCopyAmount: _num(json['minCopyAmount']),
    experienceYears: _int(json['experienceYears']),
    isCopying: json['isCopying'] as bool? ?? false,
    recentTrades: tradesRaw
        .map((e) => parseCopyTraderTrade(e as Map<String, dynamic>))
        .toList(),
  );
}

CopySubscriptionModel parseCopySubscription(Map<String, dynamic> json) =>
    CopySubscriptionModel(
      id: json['id']?.toString() ?? '',
      trader: parseCopyTrader(
        (json['trader'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      allocationInr: _num(json['allocationInr']),
      copyRatio: _num(json['copyRatio']),
      status: json['status'] as String? ?? 'active',
      autoCopy: json['autoCopy'] as bool? ?? true,
      copiedPnl: _num(json['copiedPnl']),
      startedAt: _date(json['startedAt']),
      updatedAt: _date(json['updatedAt']),
    );
