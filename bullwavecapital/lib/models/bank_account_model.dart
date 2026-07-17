class BankAccountModel {
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String maskedAccountNumber;
  final String ifsc;
  final String panNumber;
  final bool isVerified;
  final String verificationStatus;
  final String nameAtBank;
  final String nameMatchResult;
  final String panRegisteredName;
  final String verificationMessage;

  const BankAccountModel({
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.maskedAccountNumber,
    required this.ifsc,
    required this.panNumber,
    required this.isVerified,
    required this.verificationStatus,
    required this.nameAtBank,
    required this.nameMatchResult,
    required this.panRegisteredName,
    required this.verificationMessage,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) => BankAccountModel(
        accountHolderName: json['accountHolderName'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        maskedAccountNumber: json['maskedAccountNumber'] as String? ?? '',
        ifsc: json['ifsc'] as String? ?? '',
        panNumber: json['panNumber'] as String? ?? '',
        isVerified: json['isVerified'] as bool? ?? false,
        verificationStatus: json['verificationStatus'] as String? ?? 'pending',
        nameAtBank: json['nameAtBank'] as String? ?? '',
        nameMatchResult: json['nameMatchResult'] as String? ?? '',
        panRegisteredName: json['panRegisteredName'] as String? ?? '',
        verificationMessage: json['verificationMessage'] as String? ?? '',
      );
}

class BankVerificationResponse {
  final bool success;
  final String message;
  final String? nameAtBank;
  final String? nameMatchResult;
  final String? panRegisteredName;
  final String? bank;
  final String? branch;

  const BankVerificationResponse({
    required this.success,
    required this.message,
    this.nameAtBank,
    this.nameMatchResult,
    this.panRegisteredName,
    this.bank,
    this.branch,
  });

  factory BankVerificationResponse.fromJson(Map<String, dynamic> json) =>
      BankVerificationResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        nameAtBank: json['nameAtBank'] as String?,
        nameMatchResult: json['nameMatchResult'] as String?,
        panRegisteredName: json['panRegisteredName'] as String?,
        bank: json['bank'] as String?,
        branch: json['branch'] as String?,
      );
}
