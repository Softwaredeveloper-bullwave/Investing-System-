class TraderNoteModel {
  final String id;
  final String title;
  final String body;
  final String symbol;
  final String category;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TraderNoteModel({
    required this.id,
    required this.title,
    required this.body,
    required this.symbol,
    required this.category,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  String get preview {
    final text = body.trim();
    if (text.isEmpty) return 'No content yet';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  String get categoryLabel {
    switch (category) {
      case 'stock':
        return 'Stock';
      case 'trade_idea':
        return 'Trade Idea';
      case 'journal':
        return 'Journal';
      default:
        return 'General';
    }
  }
}
