/// Unified paper-trading portfolio — equity + option + commodity paper
/// positions, all sharing one PaperWallet, with live mark-to-market P&L.
class PaperPortfolioModel {
  final double virtualBalance;
  final double virtualStartingBalance;
  final double totalInvested;
  final double totalCurrentValue;
  final double totalUnrealizedPnl;
  final double totalUnrealizedPnlPercent;
  final double totalEquity;
  final double totalReturnPercent;
  final PaperPortfolioBucket equity;
  final PaperPortfolioBucket options;
  final PaperPortfolioBucket commodities;

  const PaperPortfolioModel({
    required this.virtualBalance,
    required this.virtualStartingBalance,
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalUnrealizedPnl,
    required this.totalUnrealizedPnlPercent,
    required this.totalEquity,
    required this.totalReturnPercent,
    required this.equity,
    required this.options,
    required this.commodities,
  });

  static const empty = PaperPortfolioModel(
    virtualBalance: 0,
    virtualStartingBalance: 0,
    totalInvested: 0,
    totalCurrentValue: 0,
    totalUnrealizedPnl: 0,
    totalUnrealizedPnlPercent: 0,
    totalEquity: 0,
    totalReturnPercent: 0,
    equity: PaperPortfolioBucket.empty,
    options: PaperPortfolioBucket.empty,
    commodities: PaperPortfolioBucket.empty,
  );

  bool get isProfit => totalUnrealizedPnl >= 0;
}

class PaperPortfolioBucket {
  final double invested;
  final double currentValue;
  final double unrealizedPnl;
  final int count;
  final List<Map<String, dynamic>> holdings;

  const PaperPortfolioBucket({
    required this.invested,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.count,
    required this.holdings,
  });

  static const empty = PaperPortfolioBucket(
    invested: 0, currentValue: 0, unrealizedPnl: 0, count: 0, holdings: [],
  );

  bool get isProfit => unrealizedPnl >= 0;
}
