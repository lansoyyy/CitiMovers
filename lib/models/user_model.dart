import '../utils/app_constants.dart';

class UserModel {
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? photoUrl;
  final String userType;
  final String customerAccountType;
  final Map<String, double> contractRates;
  final int billingCycleDays;
  final double walletBalance;
  final List<String> favoriteLocations;
  final bool? emailVerified;
  final String? password;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.photoUrl,
    this.userType = 'customer',
    this.customerAccountType = AppConstants.customerAccountTypeCod,
    this.contractRates = const {},
    this.billingCycleDays = AppConstants.defaultContractBillingCycleDays,
    this.walletBalance = 0.0,
    this.favoriteLocations = const [],
    this.emailVerified,
    this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isContractCustomer =>
      customerAccountType == AppConstants.customerAccountTypeWarehouseContract;

  bool get isCodCustomer =>
      customerAccountType == AppConstants.customerAccountTypeCod;

  static Map<String, double> _parseContractRates(dynamic raw) {
    if (raw is! Map) return const {};
    final parsed = <String, double>{};
    raw.forEach((key, value) {
      final amount = switch (value) {
        num v => v.toDouble(),
        String v => double.tryParse(v),
        _ => null,
      };
      if (amount != null) {
        parsed[key.toString()] = amount;
      }
    });
    return parsed;
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      'userType': userType,
      'customerAccountType': customerAccountType,
      'contractRates': contractRates,
      'billingCycleDays': billingCycleDays,
      'walletBalance': walletBalance,
      'favoriteLocations': favoriteLocations,
      'emailVerified': emailVerified,
      'password': password,
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
      customerAccountType: (map['customerAccountType'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? AppConstants.customerAccountTypeCod
          : map['customerAccountType'].toString(),
      contractRates: _parseContractRates(map['contractRates']),
      billingCycleDays: switch (map['billingCycleDays']) {
        num v => v.toInt(),
        String v => int.tryParse(v) ??
            AppConstants.defaultContractBillingCycleDays,
        _ => AppConstants.defaultContractBillingCycleDays,
      },
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      favoriteLocations: List<String>.from(map['favoriteLocations'] ?? []),
      emailVerified: map['emailVerified'],
      password: map['password'],
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
    String? customerAccountType,
    Map<String, double>? contractRates,
    int? billingCycleDays,
    double? walletBalance,
    List<String>? favoriteLocations,
    bool? emailVerified,
    String? password,
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
      customerAccountType: customerAccountType ?? this.customerAccountType,
      contractRates: contractRates ?? this.contractRates,
      billingCycleDays: billingCycleDays ?? this.billingCycleDays,
      walletBalance: walletBalance ?? this.walletBalance,
      favoriteLocations: favoriteLocations ?? this.favoriteLocations,
      emailVerified: emailVerified ?? this.emailVerified,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
