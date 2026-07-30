/// Instant KYC status — typed PAN (Eko PAN Lite) + Aadhaar (Eko
/// DigiLocker), no photo uploads, no admin review. See
/// `GET /api/v1/kyc/instant/status/` and `kyc.instant_service` on the
/// backend.
class InstantKycStatusModel {
  final String panStatus;
  final String panNumber;
  final String panName;
  final String? panVerifiedAt;
  final String panFailureReason;

  final String aadhaarStatus;
  final bool aadhaarStarted;
  final String aadhaarName;
  final String aadhaarLast4;
  final String? aadhaarVerifiedAt;
  final String aadhaarFailureReason;

  final String overallStatus;
  final String kycStatus;

  const InstantKycStatusModel({
    required this.panStatus,
    required this.panNumber,
    required this.panName,
    this.panVerifiedAt,
    required this.panFailureReason,
    required this.aadhaarStatus,
    this.aadhaarStarted = false,
    required this.aadhaarName,
    required this.aadhaarLast4,
    this.aadhaarVerifiedAt,
    required this.aadhaarFailureReason,
    required this.overallStatus,
    required this.kycStatus,
  });

  static const empty = InstantKycStatusModel(
    panStatus: 'pending',
    panNumber: '',
    panName: '',
    panFailureReason: '',
    aadhaarStatus: 'pending',
    aadhaarName: '',
    aadhaarLast4: '',
    aadhaarFailureReason: '',
    overallStatus: 'pending',
    kycStatus: 'not_submitted',
  );

  factory InstantKycStatusModel.fromJson(Map<String, dynamic> json) => InstantKycStatusModel(
        panStatus: (json['panStatus'] as String? ?? 'pending').toLowerCase(),
        panNumber: json['panNumber'] as String? ?? '',
        panName: json['panName'] as String? ?? '',
        panVerifiedAt: json['panVerifiedAt'] as String?,
        panFailureReason: json['panFailureReason'] as String? ?? '',
        aadhaarStatus: (json['aadhaarStatus'] as String? ?? 'pending').toLowerCase(),
        aadhaarStarted: json['aadhaarStarted'] as bool? ?? false,
        aadhaarName: json['aadhaarName'] as String? ?? '',
        aadhaarLast4: json['aadhaarLast4'] as String? ?? '',
        aadhaarVerifiedAt: json['aadhaarVerifiedAt'] as String?,
        aadhaarFailureReason: json['aadhaarFailureReason'] as String? ?? '',
        overallStatus: (json['overallStatus'] as String? ?? 'pending').toLowerCase(),
        kycStatus: (json['kycStatus'] as String? ?? 'not_submitted').toLowerCase(),
      );

  bool get isPanVerified => panStatus == 'verified';
  bool get isAadhaarVerified => aadhaarStatus == 'verified';
  bool get aadhaarReferenceKnown => aadhaarStarted;
  bool get isFullyVerified => isPanVerified && isAadhaarVerified;
}

/// Result of starting a DigiLocker Aadhaar session —
/// `POST /kyc/instant/aadhaar/start/`.
class DigilockerSessionModel {
  final String referenceId;
  final String url;

  const DigilockerSessionModel({required this.referenceId, required this.url});

  factory DigilockerSessionModel.fromJson(Map<String, dynamic> json) => DigilockerSessionModel(
        referenceId: json['referenceId']?.toString() ?? '',
        url: json['url'] as String? ?? '',
      );
}
