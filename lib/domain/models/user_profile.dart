class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
  });

  factory UserProfile.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
    };
  }
}
