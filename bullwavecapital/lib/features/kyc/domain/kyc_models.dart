class KycStatusModel {
  final bool mobileVerified;
  final bool panVerified;
  final bool bankVerified;
  final bool nameMatchPassed;
  final String overallStatus;
  final String panNumberMasked;
  final String panName;
  final String panStatus;
  final String bankName;
  final String bankBranch;
  final String accountHolderName;
  final String bankAccountMasked;
  final String ifsc;
  final String bankStatus;
  final String nameAtBank;
  final String nameMatchResult;
  final double nameMatchScore;
  final String? verifiedAt;

  const KycStatusModel({
    required this.mobileVerified,
    required this.panVerified,
    required this.bankVerified,
    required this.nameMatchPassed,
    required this.overallStatus,
    required this.panNumberMasked,
    required this.panName,
    required this.panStatus,
    required this.bankName,
    required this.bankBranch,
    required this.accountHolderName,
    required this.bankAccountMasked,
    required this.ifsc,
    required this.bankStatus,
    required this.nameAtBank,
    required this.nameMatchResult,
    required this.nameMatchScore,
    this.verifiedAt,
  });

  bool get isFullyVerified => overallStatus.toLowerCase() == 'verified';

  factory KycStatusModel.fromJson(Map<String, dynamic> json) => KycStatusModel(
        mobileVerified: json['mobileVerified'] as bool? ?? false,
        panVerified: json['panVerified'] as bool? ?? false,
        bankVerified: json['bankVerified'] as bool? ?? false,
        nameMatchPassed: json['nameMatchPassed'] as bool? ?? false,
        overallStatus: json['overallStatus'] as String? ?? 'pending',
        panNumberMasked: json['panNumberMasked'] as String? ?? '',
        panName: json['panName'] as String? ?? '',
        panStatus: json['panStatus'] as String? ?? 'pending',
        bankName: json['bankName'] as String? ?? '',
        bankBranch: json['bankBranch'] as String? ?? '',
        accountHolderName: json['accountHolderName'] as String? ?? '',
        bankAccountMasked: json['bankAccountMasked'] as String? ?? '',
        ifsc: json['ifsc'] as String? ?? '',
        bankStatus: json['bankStatus'] as String? ?? 'pending',
        nameAtBank: json['nameAtBank'] as String? ?? '',
        nameMatchResult: json['nameMatchResult'] as String? ?? '',
        nameMatchScore: (json['nameMatchScore'] as num?)?.toDouble() ?? 0,
        verifiedAt: json['verifiedAt'] as String?,
      );

  static const empty = KycStatusModel(
    mobileVerified: false,
    panVerified: false,
    bankVerified: false,
    nameMatchPassed: false,
    overallStatus: 'pending',
    panNumberMasked: '',
    panName: '',
    panStatus: 'pending',
    bankName: '',
    bankBranch: '',
    accountHolderName: '',
    bankAccountMasked: '',
    ifsc: '',
    bankStatus: 'pending',
    nameAtBank: '',
    nameMatchResult: '',
    nameMatchScore: 0,
  );
}

class PaymentSessionModel {
  final String orderId;
  final String paymentSessionId;
  final double amount;
  final String currency;
  final String environment;
  final bool devMode;
  final bool success;
  final String message;

  const PaymentSessionModel({
    required this.orderId,
    required this.paymentSessionId,
    required this.amount,
    required this.currency,
    required this.environment,
    this.devMode = false,
    this.success = false,
    this.message = '',
  });

  factory PaymentSessionModel.fromJson(Map<String, dynamic> json) => PaymentSessionModel(
        orderId: json['orderId'] as String? ?? '',
        paymentSessionId: json['paymentSessionId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        environment: json['environment'] as String? ?? 'SANDBOX',
        devMode: json['devMode'] as bool? ?? false,
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );
}

class WithdrawResultModel {
  final bool success;
  final String referenceId;
  final String status;
  final double balance;

  const WithdrawResultModel({
    required this.success,
    required this.referenceId,
    required this.status,
    required this.balance,
  });

  factory WithdrawResultModel.fromJson(Map<String, dynamic> json) => WithdrawResultModel(
        success: json['success'] as bool? ?? false,
        referenceId: json['referenceId'] as String? ?? '',
        status: json['status'] as String? ?? 'submitted',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}
