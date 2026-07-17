class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String panStatus;
  final String kycStatus;
  final String avatarUrl;
  final String city;
  final String bio;
  final DateTime? dateOfBirth;
  final bool hasCompletedOnboarding;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.panStatus,
    required this.kycStatus,
    required this.avatarUrl,
    this.city = '',
    this.bio = '',
    this.dateOfBirth,
    this.hasCompletedOnboarding = false,
  });

  String get displayName => name.trim().isNotEmpty ? name.trim() : 'Investor';

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? city,
    String? bio,
    DateTime? dateOfBirth,
    bool? hasCompletedOnboarding,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        panStatus: panStatus,
        kycStatus: kycStatus,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        city: city ?? this.city,
        bio: bio ?? this.bio,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      );

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email'] as String? ?? '',
        panStatus: json['panStatus'] as String? ?? 'Pending',
        kycStatus: json['kycStatus'] as String? ?? 'Pending',
        avatarUrl: json['avatarUrl'] as String? ?? '',
        city: json['city'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] != null && json['dateOfBirth'].toString().isNotEmpty
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
        hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      );
}
