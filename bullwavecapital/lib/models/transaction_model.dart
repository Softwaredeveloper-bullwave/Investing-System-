enum TransactionType { investment, profit, withdrawal, all }

enum TransactionStatus { completed, pending, failed }

class TransactionModel {
  final String id;
  final String referenceId;
  final TransactionType type;
  final TransactionStatus status;
  final double amount;
  final DateTime date;
  final String description;

  const TransactionModel({
    required this.id,
    required this.referenceId,
    required this.type,
    required this.status,
    required this.amount,
    required this.date,
    required this.description,
  });
}
