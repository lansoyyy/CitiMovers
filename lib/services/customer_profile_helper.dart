import '../models/user_model.dart';
import '../utils/app_constants.dart';

class CustomerProfileHelper {
  CustomerProfileHelper._();

  static String resolveAccountType(UserModel? user) {
    if (user == null) return AppConstants.customerAccountTypeCod;
    return user.customerAccountType;
  }

  static String resolveAccountTypeFromMap(Map<String, dynamic>? data) {
    if (data == null) return AppConstants.customerAccountTypeCod;
    final raw = (data['customerAccountType'] ?? '').toString().trim();
    if (raw.isEmpty) return AppConstants.customerAccountTypeCod;
    return raw;
  }

  static bool isCodCustomer(UserModel? user) {
    return resolveAccountType(user) == AppConstants.customerAccountTypeCod;
  }

  static bool isContractCustomer(UserModel? user) {
    return resolveAccountType(user) ==
        AppConstants.customerAccountTypeWarehouseContract;
  }

  static bool isCodFromMap(Map<String, dynamic>? data) {
    return resolveAccountTypeFromMap(data) ==
        AppConstants.customerAccountTypeCod;
  }

  static bool isContractFromMap(Map<String, dynamic>? data) {
    return resolveAccountTypeFromMap(data) ==
        AppConstants.customerAccountTypeWarehouseContract;
  }

  static bool shouldShowFare(UserModel? user) {
    return isCodCustomer(user);
  }

  static bool shouldUseWallet(UserModel? user) {
    return isCodCustomer(user);
  }

  static bool shouldShowTips(UserModel? user) {
    return isCodCustomer(user);
  }

  static String accountTypeLabel(String accountType) {
    switch (accountType) {
      case AppConstants.customerAccountTypeWarehouseContract:
        return 'Warehouse Contract';
      case AppConstants.customerAccountTypeCod:
      default:
        return 'Regular Customer (COD)';
    }
  }
}
