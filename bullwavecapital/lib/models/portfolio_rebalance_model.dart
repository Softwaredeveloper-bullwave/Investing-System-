class PortfolioRebalanceModel {
  final int driftScore;
  final bool needsRebalance;
  final String headline;
  final String message;
  final bool notificationCreated;
  final bool automationEnabled;
  final int holdingsCount;
  final double portfolioValue;
  final List<RebalanceAction> actions;

  const PortfolioRebalanceModel({
    required this.driftScore,
    required this.needsRebalance,
    required this.headline,
    required this.message,
    required this.notificationCreated,
    required this.automationEnabled,
    required this.holdingsCount,
    required this.portfolioValue,
    this.actions = const [],
  });

  factory PortfolioRebalanceModel.fromJson(Map<String, dynamic> json) {
    final actionsRaw = json['actions'] as List<dynamic>? ?? [];
    return PortfolioRebalanceModel(
      driftScore: _int(json['driftScore']),
      needsRebalance: json['needsRebalance'] as bool? ?? false,
      headline: json['headline'] as String? ?? '',
      message: json['message'] as String? ?? '',
      notificationCreated: json['notificationCreated'] as bool? ?? false,
      automationEnabled: json['automationEnabled'] as bool? ?? true,
      holdingsCount: _int(json['holdingsCount']),
      portfolioValue: _double(json['portfolioValue']),
      actions: actionsRaw
          .map((e) => RebalanceAction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RebalanceAction {
  final String type;
  final String label;
  final String detail;

  const RebalanceAction({
    required this.type,
    required this.label,
    required this.detail,
  });

  factory RebalanceAction.fromJson(Map<String, dynamic> json) => RebalanceAction(
        type: json['type'] as String? ?? '',
        label: json['label'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
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
