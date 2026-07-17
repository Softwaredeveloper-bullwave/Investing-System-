class CopyTraderModel {
  final String id;
  final String displayName;
  final String handle;
  final String avatarColor;
  final String bio;
  final String strategyTitle;
  final String strategySummary;
  final List<String> methodTags;
  final String riskLevel;
  final bool isVerified;
  final double return1m;
  final double return3m;
  final double return1y;
  final double winRate;
  final double maxDrawdown;
  final int followersCount;
  final double aumInr;
  final double minCopyAmount;
  final int experienceYears;
  final bool isCopying;
  final List<CopyTraderTradeModel> recentTrades;

  const CopyTraderModel({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.avatarColor,
    required this.bio,
    required this.strategyTitle,
    required this.strategySummary,
    required this.methodTags,
    required this.riskLevel,
    required this.isVerified,
    required this.return1m,
    required this.return3m,
    required this.return1y,
    required this.winRate,
    required this.maxDrawdown,
    required this.followersCount,
    required this.aumInr,
    required this.minCopyAmount,
    required this.experienceYears,
    this.isCopying = false,
    this.recentTrades = const [],
  });

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get riskLabel {
    switch (riskLevel) {
      case 'low':
        return 'Low risk';
      case 'high':
        return 'High risk';
      default:
        return 'Medium risk';
    }
  }

  CopyTraderModel copyWith({
    bool? isCopying,
    int? followersCount,
    List<CopyTraderTradeModel>? recentTrades,
  }) {
    return CopyTraderModel(
      id: id,
      displayName: displayName,
      handle: handle,
      avatarColor: avatarColor,
      bio: bio,
      strategyTitle: strategyTitle,
      strategySummary: strategySummary,
      methodTags: methodTags,
      riskLevel: riskLevel,
      isVerified: isVerified,
      return1m: return1m,
      return3m: return3m,
      return1y: return1y,
      winRate: winRate,
      maxDrawdown: maxDrawdown,
      followersCount: followersCount ?? this.followersCount,
      aumInr: aumInr,
      minCopyAmount: minCopyAmount,
      experienceYears: experienceYears,
      isCopying: isCopying ?? this.isCopying,
      recentTrades: recentTrades ?? this.recentTrades,
    );
  }
}

class CopyTraderTradeModel {
  final String id;
  final String symbol;
  final String side;
  final int quantity;
  final double price;
  final double? pnlPercent;
  final String note;
  final DateTime executedAt;

  const CopyTraderTradeModel({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    required this.pnlPercent,
    required this.note,
    required this.executedAt,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
}

class CopySubscriptionModel {
  final String id;
  final CopyTraderModel trader;
  final double allocationInr;
  final double copyRatio;
  final String status;
  final bool autoCopy;
  final double copiedPnl;
  final DateTime startedAt;
  final DateTime updatedAt;

  const CopySubscriptionModel({
    required this.id,
    required this.trader,
    required this.allocationInr,
    required this.copyRatio,
    required this.status,
    required this.autoCopy,
    required this.copiedPnl,
    required this.startedAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
}
