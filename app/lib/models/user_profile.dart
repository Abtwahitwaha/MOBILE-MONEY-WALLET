class UserProfile {
  final int id;
  final String fullName;
  final String phoneNumber;
  final String email;
  final String? createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['user_id'] as int,
        fullName: j['full_name'] as String,
        phoneNumber: j['phone_number'] as String,
        email: j['email'] as String,
        createdAt: j['created_at'] as String?,
      );

  String get firstName => fullName.trim().split(' ').first;
}
