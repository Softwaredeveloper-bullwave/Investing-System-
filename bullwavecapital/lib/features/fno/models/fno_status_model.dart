class FnoProofOptionModel {
  final String type;
  final String label;
  final bool requiresUpload;

  const FnoProofOptionModel({
    required this.type,
    required this.label,
    required this.requiresUpload,
  });

  factory FnoProofOptionModel.fromJson(Map<String, dynamic> json) => FnoProofOptionModel(
        type: json['type'] as String? ?? '',
        label: json['label'] as String? ?? '',
        requiresUpload: json['requiresUpload'] as bool? ?? true,
      );
}

class FnoRequestModel {
  final String id;
  final String proofType;
  final String proofLabel;
  final String status;
  final double portfolioValue;
  final String? rejectionReason;

  const FnoRequestModel({
    required this.id,
    required this.proofType,
    required this.proofLabel,
    required this.status,
    required this.portfolioValue,
    this.rejectionReason,
  });

  factory FnoRequestModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FnoRequestModel(
        id: '',
        proofType: '',
        proofLabel: '',
        status: '',
        portfolioValue: 0,
      );
    }
    return FnoRequestModel(
      id: json['id']?.toString() ?? '',
      proofType: json['proofType'] as String? ?? '',
      proofLabel: json['proofLabel'] as String? ?? '',
      status: (json['status'] as String? ?? '').toUpperCase(),
      portfolioValue: _num(json['portfolioValue']),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
}

class FnoStatusModel {
  final String fnoStatus;
  final bool isVerified;
  final double portfolioValue;
  final double minPortfolioValue;
  final FnoRequestModel? latestRequest;
  final List<FnoProofOptionModel> proofOptions;

  const FnoStatusModel({
    required this.fnoStatus,
    required this.isVerified,
    required this.portfolioValue,
    required this.minPortfolioValue,
    this.latestRequest,
    this.proofOptions = const [],
  });

  static const empty = FnoStatusModel(
    fnoStatus: 'not_submitted',
    isVerified: false,
    portfolioValue: 0,
    minPortfolioValue: 50000,
  );

  factory FnoStatusModel.fromJson(Map<String, dynamic> json) => FnoStatusModel(
        fnoStatus: (json['fnoStatus'] as String? ?? 'not_submitted').toLowerCase(),
        isVerified: json['isVerified'] as bool? ?? false,
        portfolioValue: _num(json['portfolioValue']),
        minPortfolioValue: _num(json['minPortfolioValue'], fallback: 50000),
        latestRequest: json['latestRequest'] != null
            ? FnoRequestModel.fromJson(json['latestRequest'] as Map<String, dynamic>)
            : null,
        proofOptions: (json['proofOptions'] as List<dynamic>? ?? [])
            .map((e) => FnoProofOptionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isPending =>
      fnoStatus == 'pending' || (latestRequest?.isPending ?? false);

  bool get isRejected =>
      fnoStatus == 'rejected' || (latestRequest?.isRejected ?? false);
}

double _num(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}
