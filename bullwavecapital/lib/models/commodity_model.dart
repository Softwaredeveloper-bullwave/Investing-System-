class CommodityModel {
  final String id;
  final String name;
  final String shortName;
  final String category;
  final String unit;
  final String currency;
  final String icon;
  final double ltp;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double previousClose;
  final double usdInrRate;

  const CommodityModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.category,
    required this.unit,
    required this.currency,
    required this.icon,
    required this.ltp,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.previousClose,
    this.usdInrRate = 83.5,
  });

  bool get isPositive => change >= 0;
}

class CommodityHoldingModel {
  final String commodityId;
  final String name;
  final String shortName;
  final String unit;
  final int quantity;
  final double avgPriceUsd;
  final double ltpUsd;
  final double investedInr;
  final double currentValueInr;
  final double pnlInr;
  final double pnlPercent;

  const CommodityHoldingModel({
    required this.commodityId,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.quantity,
    required this.avgPriceUsd,
    required this.ltpUsd,
    required this.investedInr,
    required this.currentValueInr,
    required this.pnlInr,
    required this.pnlPercent,
  });

  bool get isProfit => pnlInr >= 0;
}

class CommodityTradeModel {
  final String id;
  final String commodityId;
  final String name;
  final String shortName;
  final String unit;
  final String side;
  final int quantity;
  final double priceUsd;
  final double amountInr;
  final double usdInrRate;
  final DateTime time;
  final String status;
  final double orderValueUsd;
  final double ltpUsd;
  final double? avgCostUsd;
  final double? realizedPnlInr;
  final int? holdingQty;
  final double? holdingAvgPriceUsd;

  const CommodityTradeModel({
    required this.id,
    required this.commodityId,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.side,
    required this.quantity,
    required this.priceUsd,
    required this.amountInr,
    required this.usdInrRate,
    required this.time,
    required this.status,
    required this.orderValueUsd,
    required this.ltpUsd,
    this.avgCostUsd,
    this.realizedPnlInr,
    this.holdingQty,
    this.holdingAvgPriceUsd,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isSell => side.toUpperCase() == 'SELL';
}
