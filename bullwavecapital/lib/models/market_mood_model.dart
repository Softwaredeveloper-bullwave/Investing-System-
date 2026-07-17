class MarketMoodModel {
  final double score;
  final String mood;
  final String moodLabel;
  final double indexChangePercent;
  final int advancers;
  final int decliners;
  final int universeSize;
  final String commentary;
  final bool aiGenerated;
  final DateTime generatedAt;

  const MarketMoodModel({
    required this.score,
    required this.mood,
    required this.moodLabel,
    required this.indexChangePercent,
    required this.advancers,
    required this.decliners,
    required this.universeSize,
    required this.commentary,
    required this.aiGenerated,
    required this.generatedAt,
  });

  factory MarketMoodModel.fromJson(Map<String, dynamic> json) {
    return MarketMoodModel(
      score: (json['score'] as num?)?.toDouble() ?? 50,
      mood: json['mood']?.toString() ?? 'neutral',
      moodLabel: json['moodLabel']?.toString() ?? 'Neutral',
      indexChangePercent: (json['indexChangePercent'] as num?)?.toDouble() ?? 0,
      advancers: (json['advancers'] as num?)?.toInt() ?? 0,
      decliners: (json['decliners'] as num?)?.toInt() ?? 0,
      universeSize: (json['universeSize'] as num?)?.toInt() ?? 0,
      commentary: json['commentary']?.toString() ?? '',
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
