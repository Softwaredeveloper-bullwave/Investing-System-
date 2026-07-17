class WalletModel {
  final double balance;
  final String bankName;
  final String accountNumber;
  final String ifsc;

  const WalletModel({
    required this.balance,
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        balance: (json['balance'] as num).toDouble(),
        bankName: json['bankName'] as String,
        accountNumber: json['accountNumber'] as String,
        ifsc: json['ifsc'] as String,
      );
}

class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String status;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
  });
}
