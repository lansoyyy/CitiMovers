class UserModel {
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? photoUrl;
  final String userType;
  final double walletBalance;
  final List<String> favoriteLocations;
  final bool? emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.photoUrl,
    this.userType = 'customer',
    this.walletBalance = 0.0,
    this.favoriteLocations = const [],
    this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      'userType': userType,
      'walletBalance': walletBalance,
      'favoriteLocations': favoriteLocations,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create UserModel from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      photoUrl: map['photoUrl'],
      userType: map['userType'] ?? 'customer',
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      favoriteLocations: List<String>.from(map['favoriteLocations'] ?? []),
      emailVerified: map['emailVerified'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // Copy with method for updating user data
  UserModel copyWith({
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? photoUrl,
    String? userType,
    double? walletBalance,
    List<String>? favoriteLocations,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      walletBalance: walletBalance ?? this.walletBalance,
      favoriteLocations: favoriteLocations ?? this.favoriteLocations,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
