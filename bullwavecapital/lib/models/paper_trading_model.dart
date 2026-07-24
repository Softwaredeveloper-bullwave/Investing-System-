/// Models for the Paper Trading module — order book (market/limit/SL-M/SL),
/// funds ledger, trading journal, performance analytics, and risk limits.
/// Deliberately separate from [PaperTradeModel] in stock_model.dart (the
/// legacy market-only fill record), which stays untouched.
library;

class PaperOrderModel {
  final String id;
  final String symbol;
  final String stockName;
  final String side;
  final String orderType;
  final int quantity;
  final double? limitPrice;
  final double? triggerPrice;
  final String status;
  final double? executedPrice;
  final double charges;
  final String rejectReason;
  final double ltp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? executedAt;
  final String? tradeId;

  const PaperOrderModel({
    required this.id,
    required this.symbol,
    this.stockName = '',
    required this.side,
    required this.orderType,
    required this.quantity,
    this.limitPrice,
    this.triggerPrice,
    required this.status,
    this.executedPrice,
    this.charges = 0,
    this.rejectReason = '',
    this.ltp = 0,
    required this.createdAt,
    required this.updatedAt,
    this.executedAt,
    this.tradeId,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isExecuted => status.toUpperCase() == 'EXECUTED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isMarket => orderType.toUpperCase() == 'MARKET';
  double get estimatedValue => quantity * (limitPrice ?? triggerPrice ?? ltp);
}

class PaperLedgerEntryModel {
  final String id;
  final String entryType;
  final double amount;
  final double balanceAfter;
  final String description;
  final String? orderId;
  final DateTime createdAt;

  const PaperLedgerEntryModel({
    required this.id,
    required this.entryType,
    required this.amount,
    required this.balanceAfter,
    this.description = '',
    this.orderId,
    required this.createdAt,
  });

  bool get isCredit => amount >= 0;
}

class PaperJournalEntryModel {
  final String id;
  final String? tradeId;
  final String symbol;
  final String title;
  final String notes;
  final String lessonLearned;
  final String mood;
  final int? rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaperJournalEntryModel({
    required this.id,
    this.tradeId,
    this.symbol = '',
    required this.title,
    this.notes = '',
    this.lessonLearned = '',
    this.mood = '',
    this.rating,
    required this.createdAt,
    required this.updatedAt,
  });
}

class EquityCurvePoint {
  final String? date;
  final double equity;

  const EquityCurvePoint({this.date, required this.equity});
}

class PaperAnalyticsModel {
  final int totalTrades;
  final int closedTrades;
  final int winCount;
  final int lossCount;
  final double winRatePercent;
  final double profitFactor;
  final double avgWin;
  final double avgLoss;
  final double bestTrade;
  final double worstTrade;
  final double totalRealizedPnl;
  final double currentEquity;
  final double startingBalance;
  final double totalReturnPercent;
  final double maxDrawdownAmount;
  final double maxDrawdownPercent;
  final List<EquityCurvePoint> equityCurve;

  const PaperAnalyticsModel({
    this.totalTrades = 0,
    this.closedTrades = 0,
    this.winCount = 0,
    this.lossCount = 0,
    this.winRatePercent = 0,
    this.profitFactor = 0,
    this.avgWin = 0,
    this.avgLoss = 0,
    this.bestTrade = 0,
    this.worstTrade = 0,
    this.totalRealizedPnl = 0,
    this.currentEquity = 0,
    this.startingBalance = 0,
    this.totalReturnPercent = 0,
    this.maxDrawdownAmount = 0,
    this.maxDrawdownPercent = 0,
    this.equityCurve = const [],
  });

  static const empty = PaperAnalyticsModel();
}

class PaperRiskLimitModel {
  final double? maxDailyLoss;
  final double maxPositionSizePercent;
  final bool isActive;

  const PaperRiskLimitModel({
    this.maxDailyLoss,
    this.maxPositionSizePercent = 20,
    this.isActive = true,
  });
}

class PositionBreachModel {
  final String symbol;
  final double positionPercent;
  final double limitPercent;

  const PositionBreachModel({
    required this.symbol,
    required this.positionPercent,
    required this.limitPercent,
  });
}

class PaperRiskStatusModel {
  final PaperRiskLimitModel limit;
  final double dailyPnl;
  final double dailyLoss;
  final bool dailyLossBreached;
  final List<PositionBreachModel> positionBreaches;
  final double currentEquity;

  const PaperRiskStatusModel({
    this.limit = const PaperRiskLimitModel(),
    this.dailyPnl = 0,
    this.dailyLoss = 0,
    this.dailyLossBreached = false,
    this.positionBreaches = const [],
    this.currentEquity = 0,
  });

  static const empty = PaperRiskStatusModel();
}
