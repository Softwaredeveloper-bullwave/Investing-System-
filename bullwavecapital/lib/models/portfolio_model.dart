class PortfolioModel {
  final double totalInvestment;
  final double currentValue;
  final double monthlyProfit;
  final double totalProfit;
  final double growthPercent;
  final double dayPnl;
  final double dayPnlPercent;
  final int holdingsCount;
  final double stocksInvested;
  final double stocksValue;
  final double walletBalance;

  const PortfolioModel({
    required this.totalInvestment,
    required this.currentValue,
    required this.monthlyProfit,
    required this.totalProfit,
    required this.growthPercent,
    this.dayPnl = 0,
    this.dayPnlPercent = 0,
    this.holdingsCount = 0,
    this.stocksInvested = 0,
    this.stocksValue = 0,
    this.walletBalance = 0,
  });

  factory PortfolioModel.fromJson(Map<String, dynamic> json) {
    double read(String key) {
      final v = json[key];
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0;
      return 0;
    }

    int readInt(String key) {
      final v = json[key];
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? 0;
      return 0;
    }

    return PortfolioModel(
      totalInvestment: read('totalInvestment'),
      currentValue: read('currentValue'),
      monthlyProfit: read('monthlyProfit'),
      totalProfit: read('totalProfit'),
      growthPercent: read('growthPercent'),
      dayPnl: read('dayPnl'),
      dayPnlPercent: read('dayPnlPercent'),
      holdingsCount: readInt('holdingsCount'),
      stocksInvested: read('stocksInvested'),
      stocksValue: read('stocksValue'),
      walletBalance: read('walletBalance'),
    );
  }
}

class AllocationItem {
  final String label;
  final double percentage;
  final int colorValue;

  const AllocationItem({
    required this.label,
    required this.percentage,
    required this.colorValue,
  });
}

class MonthlyEarning {
  final String month;
  final double amount;

  const MonthlyEarning({required this.month, required this.amount});
}

class PortfolioSummaryModel {
  final double totalInvested;
  final double currentValue;
  final double totalPnl;
  final double totalPnlPercent;
  final double dayPnl;
  final double dayPnlPercent;
  final int holdingsCount;

  const PortfolioSummaryModel({
    required this.totalInvested,
    required this.currentValue,
    required this.totalPnl,
    required this.totalPnlPercent,
    required this.dayPnl,
    required this.dayPnlPercent,
    required this.holdingsCount,
  });

  static const empty = PortfolioSummaryModel(
    totalInvested: 0,
    currentValue: 0,
    totalPnl: 0,
    totalPnlPercent: 0,
    dayPnl: 0,
    dayPnlPercent: 0,
    holdingsCount: 0,
  );
}

class SectorAllocationItem {
  final String label;
  final double value;
  final double percentage;
  final int colorValue;

  const SectorAllocationItem({
    required this.label,
    required this.value,
    required this.percentage,
    required this.colorValue,
  });
}
