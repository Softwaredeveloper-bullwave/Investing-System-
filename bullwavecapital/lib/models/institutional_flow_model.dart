class BlockDealModel {
  final String id;
  final String symbol;
  final String companyName;
  final String exchange;
  final String dealType;
  final String side;
  final double price;
  final int quantity;
  final double valueCr;
  final double ltp;
  final double premiumPercent;
  final String clientName;
  final String counterparty;
  final DateTime tradedAt;

  const BlockDealModel({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.exchange,
    required this.dealType,
    required this.side,
    required this.price,
    required this.quantity,
    required this.valueCr,
    required this.ltp,
    required this.premiumPercent,
    required this.clientName,
    required this.counterparty,
    required this.tradedAt,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isBlock => dealType == 'block';

  factory BlockDealModel.fromJson(Map<String, dynamic> json) => BlockDealModel(
        id: json['id']?.toString() ?? '',
        symbol: json['symbol'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        exchange: json['exchange'] as String? ?? 'NSE',
        dealType: json['dealType'] as String? ?? 'block',
        side: json['side'] as String? ?? 'BUY',
        price: _d(json['price']),
        quantity: _i(json['quantity']),
        valueCr: _d(json['valueCr']),
        ltp: _d(json['ltp']),
        premiumPercent: _d(json['premiumPercent']),
        clientName: json['clientName'] as String? ?? '',
        counterparty: json['counterparty'] as String? ?? '',
        tradedAt: DateTime.tryParse(json['tradedAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class BlockDealSummary {
  final double buyValueCr;
  final double sellValueCr;
  final double netValueCr;
  final int blockCount;
  final int bulkCount;

  const BlockDealSummary({
    required this.buyValueCr,
    required this.sellValueCr,
    required this.netValueCr,
    required this.blockCount,
    required this.bulkCount,
  });

  factory BlockDealSummary.fromJson(Map<String, dynamic>? json) => BlockDealSummary(
        buyValueCr: _d(json?['buyValueCr']),
        sellValueCr: _d(json?['sellValueCr']),
        netValueCr: _d(json?['netValueCr']),
        blockCount: _i(json?['blockCount']),
        bulkCount: _i(json?['bulkCount']),
      );
}

class BlockDealsResponse {
  final List<BlockDealModel> deals;
  final BlockDealSummary summary;

  const BlockDealsResponse({required this.deals, required this.summary});
}

class DarkPoolPrintModel {
  final String id;
  final String symbol;
  final String companyName;
  final String venue;
  final double price;
  final int quantity;
  final double valueCr;
  final double vwap;
  final double vsVwapPercent;
  final String bias;
  final DateTime printTime;
  final String note;

  const DarkPoolPrintModel({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.venue,
    required this.price,
    required this.quantity,
    required this.valueCr,
    required this.vwap,
    required this.vsVwapPercent,
    required this.bias,
    required this.printTime,
    required this.note,
  });

  factory DarkPoolPrintModel.fromJson(Map<String, dynamic> json) => DarkPoolPrintModel(
        id: json['id']?.toString() ?? '',
        symbol: json['symbol'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        venue: json['venue'] as String? ?? 'Dark Pool',
        price: _d(json['price']),
        quantity: _i(json['quantity']),
        valueCr: _d(json['valueCr']),
        vwap: _d(json['vwap']),
        vsVwapPercent: _d(json['vsVwapPercent']),
        bias: json['bias'] as String? ?? 'mixed',
        printTime: DateTime.tryParse(json['printTime']?.toString() ?? '') ?? DateTime.now(),
        note: json['note'] as String? ?? '',
      );
}

class DarkPoolSummary {
  final double totalValueCr;
  final int buyBiased;
  final int sellBiased;
  final double avgVsVwap;

  const DarkPoolSummary({
    required this.totalValueCr,
    required this.buyBiased,
    required this.sellBiased,
    required this.avgVsVwap,
  });

  factory DarkPoolSummary.fromJson(Map<String, dynamic>? json) => DarkPoolSummary(
        totalValueCr: _d(json?['totalValueCr']),
        buyBiased: _i(json?['buyBiased']),
        sellBiased: _i(json?['sellBiased']),
        avgVsVwap: _d(json?['avgVsVwap']),
      );
}

class DarkPoolResponse {
  final List<DarkPoolPrintModel> prints;
  final DarkPoolSummary summary;

  const DarkPoolResponse({required this.prints, required this.summary});
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
