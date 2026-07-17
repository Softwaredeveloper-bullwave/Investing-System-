class PortfolioHealthModel {
  final int score;
  final String grade;
  final String gradeLetter;
  final String label;
  final String summary;
  final int driftScore;
  final int holdingsCount;
  final double portfolioValue;
  final double totalPnlPercent;
  final double dayPnlPercent;
  final List<HealthFactor> factors;

  const PortfolioHealthModel({
    required this.score,
    required this.grade,
    required this.gradeLetter,
    required this.label,
    required this.summary,
    required this.driftScore,
    required this.holdingsCount,
    required this.portfolioValue,
    this.totalPnlPercent = 0,
    this.dayPnlPercent = 0,
    this.factors = const [],
  });

  factory PortfolioHealthModel.fromJson(Map<String, dynamic> json) {
    final factorsRaw = json['factors'] as List<dynamic>? ?? [];
    return PortfolioHealthModel(
      score: _int(json['score']),
      grade: json['grade'] as String? ?? '—',
      gradeLetter: json['gradeLetter'] as String? ?? '—',
      label: json['label'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      driftScore: _int(json['driftScore']),
      holdingsCount: _int(json['holdingsCount']),
      portfolioValue: _double(json['portfolioValue']),
      totalPnlPercent: _double(json['totalPnlPercent']),
      dayPnlPercent: _double(json['dayPnlPercent']),
      factors: factorsRaw
          .map((e) => HealthFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HealthFactor {
  final String key;
  final String label;
  final String impact;
  final String detail;

  const HealthFactor({
    required this.key,
    required this.label,
    required this.impact,
    required this.detail,
  });

  bool get isPositive => impact == 'positive';

  factory HealthFactor.fromJson(Map<String, dynamic> json) => HealthFactor(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        impact: json['impact'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );
}

class NewsAlertModel {
  final String id;
  final String keyword;
  final bool isActive;
  final DateTime? lastMatchedAt;
  final String lastMatchedTitle;

  const NewsAlertModel({
    required this.id,
    required this.keyword,
    required this.isActive,
    this.lastMatchedAt,
    this.lastMatchedTitle = '',
  });

  factory NewsAlertModel.fromJson(Map<String, dynamic> json) => NewsAlertModel(
        id: json['id']?.toString() ?? '',
        keyword: json['keyword'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        lastMatchedAt: json['lastMatchedAt'] != null
            ? DateTime.tryParse(json['lastMatchedAt'].toString())
            : null,
        lastMatchedTitle: json['lastMatchedTitle'] as String? ?? '',
      );
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
