/// Manual KYC status from GET /api/v1/kyc/me
class ManualKycStatusModel {
  final String kycStatus;
  final KycRequestModel? latestRequest;

  const ManualKycStatusModel({
    required this.kycStatus,
    this.latestRequest,
  });

  static const empty = ManualKycStatusModel(kycStatus: 'not_submitted');

  factory ManualKycStatusModel.fromJson(Map<String, dynamic> json) =>
      ManualKycStatusModel(
        kycStatus: (json['kycStatus'] as String? ?? 'not_submitted').toLowerCase(),
        latestRequest: json['latestRequest'] != null
            ? KycRequestModel.fromJson(json['latestRequest'] as Map<String, dynamic>)
            : null,
      );

  bool get isVerified =>
      kycStatus == 'verified' || kycStatus == 'completed';

  bool get isPending =>
      kycStatus == 'pending' ||
      kycStatus == 'in_progress' ||
      (latestRequest?.isPending ?? false);

  bool get isRejected =>
      kycStatus == 'rejected' || (latestRequest?.isRejected ?? false);

  bool get needsSubmit => !isVerified && !isPending;

  String get rejectionReason => latestRequest?.rejectionReason ?? '';
}

class KycRequestModel {
  final String id;
  final String panNumber;
  final String fullName;
  final String dob;
  final String panImageUrl;
  final String status;
  final String rejectionReason;
  final String? reviewedAt;
  final String createdAt;

  const KycRequestModel({
    required this.id,
    required this.panNumber,
    required this.fullName,
    required this.dob,
    required this.panImageUrl,
    required this.status,
    this.rejectionReason = '',
    this.reviewedAt,
    required this.createdAt,
  });

  factory KycRequestModel.fromJson(Map<String, dynamic> json) => KycRequestModel(
        id: json['id']?.toString() ?? '',
        panNumber: json['panNumber'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        dob: json['dob'] as String? ?? '',
        panImageUrl: json['panImageUrl'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        rejectionReason: json['rejectionReason'] as String? ?? '',
        reviewedAt: json['reviewedAt'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
}
