class MarketIndexModel {
  final String id;
  final String name;
  final String shortName;
  final double value;
  final double change;
  final double changePercent;

  const MarketIndexModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.value,
    required this.change,
    required this.changePercent,
  });

  bool get isPositive => change >= 0;
}
