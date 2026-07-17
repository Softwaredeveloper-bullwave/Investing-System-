class StockModel {
  final String symbol;
  final String name;
  final String exchange;
  final String sector;
  final double ltp;
  final double change;
  final double changePercent;
  final double open;
  final double high;
  final double low;
  final double previousClose;
  final int volume;
  final double marketCapCr;
  final double pe;
  final double eps;
  final double week52High;
  final double week52Low;

  const StockModel({
    required this.symbol,
    required this.name,
    this.exchange = 'NSE',
    required this.sector,
    required this.ltp,
    required this.change,
    required this.changePercent,
    required this.open,
    required this.high,
    required this.low,
    required this.previousClose,
    required this.volume,
    required this.marketCapCr,
    required this.pe,
    required this.eps,
    required this.week52High,
    required this.week52Low,
  });

  bool get isPositive => change >= 0;

  StockModel copyWithLivePrice({required double ltp, required double change, required double changePercent}) {
    return StockModel(
      symbol: symbol,
      name: name,
      exchange: exchange,
      sector: sector,
      ltp: ltp,
      change: change,
      changePercent: changePercent,
      open: open,
      high: high > ltp ? high : ltp,
      low: low < ltp ? low : ltp,
      previousClose: previousClose,
      volume: volume,
      marketCapCr: marketCapCr,
      pe: pe,
      eps: eps,
      week52High: week52High,
      week52Low: week52Low,
    );
  }
}

class CandleModel {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  const CandleModel({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;
}

class StockHoldingModel {
  final String symbol;
  final String name;
  final String sector;
  final String exchange;
  final int quantity;
  final double avgPrice;
  final double ltp;
  final double change;
  final double changePercent;
  final double dayPnl;

  const StockHoldingModel({
    required this.symbol,
    required this.name,
    this.sector = '',
    this.exchange = 'NSE',
    required this.quantity,
    required this.avgPrice,
    required this.ltp,
    this.change = 0,
    this.changePercent = 0,
    this.dayPnl = 0,
  });

  double get invested => quantity * avgPrice;
  double get currentValue => quantity * ltp;
  double get pnl => currentValue - invested;
  double get pnlPercent => invested == 0 ? 0 : (pnl / invested) * 100;
  bool get isPositive => pnl >= 0;
  bool get isDayPositive => dayPnl >= 0;
}

class StockNewsModel {
  final String id;
  final String title;
  final String summary;
  final String source;
  final DateTime publishedAt;
  final List<String> relatedSymbols;
  final String category;
  final String url;
  final String imageUrl;

  const StockNewsModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.publishedAt,
    required this.relatedSymbols,
    required this.category,
    this.url = '',
    this.imageUrl = '',
  });
}

class PriceAlertModel {
  final String id;
  final String symbol;
  final String name;
  final double targetPrice;
  final String condition;
  final bool isActive;

  const PriceAlertModel({
    required this.id,
    required this.symbol,
    required this.name,
    required this.targetPrice,
    required this.condition,
    this.isActive = true,
  });
}

class SipPlanModel {
  final String id;
  final String symbol;
  final String name;
  final double monthlyAmount;
  final int installmentsDone;
  final int totalInstallments;
  final double totalInvested;
  final double currentValue;
  final DateTime nextDate;

  const SipPlanModel({
    required this.id,
    required this.symbol,
    required this.name,
    required this.monthlyAmount,
    required this.installmentsDone,
    required this.totalInstallments,
    required this.totalInvested,
    required this.currentValue,
    required this.nextDate,
  });
}

class OptionContractModel {
  final String symbol;
  final double strike;
  final String type;
  final double ltp;
  final double change;
  final int oi;
  final int volume;
  final DateTime expiry;

  const OptionContractModel({
    required this.symbol,
    required this.strike,
    required this.type,
    required this.ltp,
    required this.change,
    required this.oi,
    required this.volume,
    required this.expiry,
  });
}

class PaperTradeModel {
  final String id;
  final String symbol;
  final String stockName;
  final String side;
  final int quantity;
  final double price;
  final DateTime time;
  final String status;
  final double orderValue;
  final double? avgCost;
  final double? realizedPnl;
  final double? realizedPnlPercent;
  final int? holdingQty;
  final double? holdingAvgPrice;
  final double? unrealizedPnl;
  final double ltp;

  const PaperTradeModel({
    required this.id,
    required this.symbol,
    this.stockName = '',
    required this.side,
    required this.quantity,
    required this.price,
    required this.time,
    required this.status,
    this.orderValue = 0,
    this.avgCost,
    this.realizedPnl,
    this.realizedPnlPercent,
    this.holdingQty,
    this.holdingAvgPrice,
    this.unrealizedPnl,
    this.ltp = 0,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isSell => side.toUpperCase() == 'SELL';
  double get totalValue => orderValue > 0 ? orderValue : price * quantity;
  bool get hasRealizedPnl => realizedPnl != null;
  bool get isProfit => (realizedPnl ?? unrealizedPnl ?? 0) >= 0;
}

class DividendModel {
  final String symbol;
  final String name;
  final double amountPerShare;
  final DateTime exDate;
  final DateTime paymentDate;
  final int sharesHeld;
  final String status;

  const DividendModel({
    required this.symbol,
    required this.name,
    required this.amountPerShare,
    required this.exDate,
    required this.paymentDate,
    required this.sharesHeld,
    required this.status,
  });

  double get totalPayout => amountPerShare * sharesHeld;
}

class TechnicalIndicatorsModel {
  final double rsi;
  final String macdSignal;
  final double sma50;
  final double sma200;
  final String trend;

  const TechnicalIndicatorsModel({
    required this.rsi,
    required this.macdSignal,
    required this.sma50,
    required this.sma200,
    required this.trend,
  });
}

class AiMessageModel {
  final String role;
  final String content;
  final DateTime time;

  const AiMessageModel({
    required this.role,
    required this.content,
    required this.time,
  });
}

class ScreenerStockModel {
  final StockModel stock;
  final double roe;
  final double debtToEquity;
  final double revenueGrowth;

  const ScreenerStockModel({
    required this.stock,
    required this.roe,
    required this.debtToEquity,
    required this.revenueGrowth,
  });
}

class OptionChainResponse {
  final String symbol;
  final double underlyingValue;
  final List<String> expiryDates;
  final String selectedExpiry;
  final List<OptionContractModel> contracts;

  const OptionChainResponse({
    required this.symbol,
    required this.underlyingValue,
    required this.expiryDates,
    required this.selectedExpiry,
    required this.contracts,
  });
}

class IpoEventModel {
  final String id;
  final String companyName;
  final String symbol;
  final String sector;
  final String status;
  final DateTime? openDate;
  final DateTime? closeDate;
  final DateTime? listingDate;
  final double priceBandMin;
  final double priceBandMax;
  final double issueSizeCr;
  final int lotSize;
  final double minInvestment;
  final double? gmpPercent;
  final String? subscriptionTimes;
  final String exchange;
  final bool isFeatured;
  final String description;
  final double listingPrice;

  const IpoEventModel({
    required this.id,
    required this.companyName,
    required this.symbol,
    required this.sector,
    required this.status,
    this.openDate,
    this.closeDate,
    this.listingDate,
    required this.priceBandMin,
    required this.priceBandMax,
    required this.issueSizeCr,
    required this.lotSize,
    required this.minInvestment,
    this.gmpPercent,
    this.subscriptionTimes,
    required this.exchange,
    required this.isFeatured,
    required this.description,
    this.listingPrice = 0,
  });

  String get priceBandLabel => '₹${priceBandMin.toStringAsFixed(0)} – ₹${priceBandMax.toStringAsFixed(0)}';

  bool get isOpen => status == 'open';
  bool get isUpcoming => status == 'upcoming';
  bool get isListed => status == 'listed';

  double get applyPrice => priceBandMax;

  double costForLots(int lots) => lots * lotSize * applyPrice;
}

class IpoHoldingModel {
  final String ipoId;
  final String companyName;
  final String symbol;
  final String sector;
  final String ipoStatus;
  final int lots;
  final int quantity;
  final double avgPrice;
  final double ltp;
  final double investedInr;
  final double currentValueInr;
  final double pnlInr;
  final double pnlPercent;
  final bool canSell;

  const IpoHoldingModel({
    required this.ipoId,
    required this.companyName,
    required this.symbol,
    required this.sector,
    required this.ipoStatus,
    required this.lots,
    required this.quantity,
    required this.avgPrice,
    required this.ltp,
    required this.investedInr,
    required this.currentValueInr,
    required this.pnlInr,
    required this.pnlPercent,
    required this.canSell,
  });
}

class IpoTradeModel {
  final String id;
  final String ipoId;
  final String companyName;
  final String symbol;
  final String side;
  final int lots;
  final int quantity;
  final double price;
  final double amountInr;
  final DateTime time;
  final String status;

  const IpoTradeModel({
    required this.id,
    required this.ipoId,
    required this.companyName,
    required this.symbol,
    required this.side,
    required this.lots,
    required this.quantity,
    required this.price,
    required this.amountInr,
    required this.time,
    required this.status,
  });

  bool get isApply => side == 'APPLY';
}
