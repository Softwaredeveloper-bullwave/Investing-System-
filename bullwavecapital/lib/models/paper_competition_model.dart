class PaperRiskMeterModel {
  final int score;
  final String level;
  final String label;
  final String summary;
  final int tradesCount;
  final int recentTrades;
  final int holdingsCount;
  final double portfolioValue;
  final double dayPnlPercent;
  final List<PaperRiskFactor> factors;
  final List<PaperRiskZone> zones;

  const PaperRiskMeterModel({
    required this.score,
    required this.level,
    required this.label,
    required this.summary,
    required this.tradesCount,
    required this.recentTrades,
    required this.holdingsCount,
    required this.portfolioValue,
    required this.dayPnlPercent,
    this.factors = const [],
    this.zones = const [],
  });

  factory PaperRiskMeterModel.fromJson(Map<String, dynamic> json) {
    return PaperRiskMeterModel(
      score: _int(json['score']),
      level: json['level'] as String? ?? 'low',
      label: json['label'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      tradesCount: _int(json['tradesCount']),
      recentTrades: _int(json['recentTrades']),
      holdingsCount: _int(json['holdingsCount']),
      portfolioValue: _double(json['portfolioValue']),
      dayPnlPercent: _double(json['dayPnlPercent']),
      factors: (json['factors'] as List<dynamic>? ?? [])
          .map((e) => PaperRiskFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
      zones: (json['zones'] as List<dynamic>? ?? [])
          .map((e) => PaperRiskZone.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaperRiskFactor {
  final String key;
  final String label;
  final String impact;
  final String detail;

  const PaperRiskFactor({
    required this.key,
    required this.label,
    required this.impact,
    required this.detail,
  });

  bool get isPositive => impact == 'positive';

  factory PaperRiskFactor.fromJson(Map<String, dynamic> json) => PaperRiskFactor(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        impact: json['impact'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );
}

class PaperRiskZone {
  final String key;
  final int from;
  final int to;
  final String label;

  const PaperRiskZone({
    required this.key,
    required this.from,
    required this.to,
    required this.label,
  });

  factory PaperRiskZone.fromJson(Map<String, dynamic> json) => PaperRiskZone(
        key: json['key'] as String? ?? '',
        from: _int(json['from']),
        to: _int(json['to']),
        label: json['label'] as String? ?? '',
      );
}

class PaperCompetitionStanding {
  final String id;
  final String userId;
  final String displayName;
  final double equity;
  final double pnl;
  final double pnlPercent;
  final int tradesCount;
  final int rank;
  final bool isYou;

  const PaperCompetitionStanding({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.equity,
    required this.pnl,
    required this.pnlPercent,
    required this.tradesCount,
    required this.rank,
    required this.isYou,
  });

  factory PaperCompetitionStanding.fromJson(Map<String, dynamic> json) =>
      PaperCompetitionStanding(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        displayName: json['displayName'] as String? ?? '',
        equity: _double(json['equity']),
        pnl: _double(json['pnl']),
        pnlPercent: _double(json['pnlPercent']),
        tradesCount: _int(json['tradesCount']),
        rank: _int(json['rank']),
        isYou: json['isYou'] as bool? ?? false,
      );
}

class PaperCompetitionModel {
  final String id;
  final String name;
  final String inviteCode;
  final double startingBalance;
  final String status;
  final int durationDays;
  final DateTime startsAt;
  final DateTime endsAt;
  final int membersCount;
  final bool isHost;
  final String shareMessage;
  final PaperCompetitionStanding? you;
  final List<PaperCompetitionStanding> standings;

  const PaperCompetitionModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.startingBalance,
    required this.status,
    required this.durationDays,
    required this.startsAt,
    required this.endsAt,
    required this.membersCount,
    required this.isHost,
    required this.shareMessage,
    this.you,
    this.standings = const [],
  });

  factory PaperCompetitionModel.fromJson(Map<String, dynamic> json) {
    final youRaw = json['you'];
    return PaperCompetitionModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      startingBalance: _double(json['startingBalance']),
      status: json['status'] as String? ?? 'open',
      durationDays: _int(json['durationDays']),
      startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now(),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? '') ?? DateTime.now(),
      membersCount: _int(json['membersCount']),
      isHost: json['isHost'] as bool? ?? false,
      shareMessage: json['shareMessage'] as String? ?? '',
      you: youRaw is Map<String, dynamic>
          ? PaperCompetitionStanding.fromJson(youRaw)
          : null,
      standings: (json['standings'] as List<dynamic>? ?? [])
          .map((e) => PaperCompetitionStanding.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
