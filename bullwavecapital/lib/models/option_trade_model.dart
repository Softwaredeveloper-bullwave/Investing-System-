class OptionHoldingModel {
  final String underlying;
  final String assetClass;
  final double strike;
  final String optionType;
  final DateTime expiry;
  final String contractLabel;
  final int quantity;
  final double avgPremium;
  final int lotSize;
  // Live mark-to-market — populated by the paper-trading holdings endpoint
  // (`ltpPremium`/`currentValueInr`/`unrealizedPnlInr`); null for the real
  // options endpoint, which doesn't compute these server-side.
  final double? ltpPremium;
  final double? currentValueInr;
  final double? unrealizedPnlInr;

  const OptionHoldingModel({
    required this.underlying,
    required this.assetClass,
    required this.strike,
    required this.optionType,
    required this.expiry,
    required this.contractLabel,
    required this.quantity,
    required this.avgPremium,
    required this.lotSize,
    this.ltpPremium,
    this.currentValueInr,
    this.unrealizedPnlInr,
  });

  bool get hasLiveMark => ltpPremium != null;
  bool get isProfit => (unrealizedPnlInr ?? 0) >= 0;
}

class OptionTradeModel {
  final String id;
  final String underlying;
  final String assetClass;
  final double strike;
  final String optionType;
  final DateTime expiry;
  final String contractLabel;
  final String side;
  final int quantity;
  final double premium;
  final int lotSize;
  final double amountInr;
  final DateTime time;
  final String status;
  final double? avgPremium;
  final double? realizedPnlInr;
  final int? holdingQty;

  const OptionTradeModel({
    required this.id,
    required this.underlying,
    required this.assetClass,
    required this.strike,
    required this.optionType,
    required this.expiry,
    required this.contractLabel,
    required this.side,
    required this.quantity,
    required this.premium,
    required this.lotSize,
    required this.amountInr,
    required this.time,
    required this.status,
    this.avgPremium,
    this.realizedPnlInr,
    this.holdingQty,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isSell => side.toUpperCase() == 'SELL';
}
