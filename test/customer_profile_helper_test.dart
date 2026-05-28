import 'package:citimovers/models/user_model.dart';
import 'package:citimovers/services/customer_profile_helper.dart';
import 'package:citimovers/utils/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerProfileHelper', () {
    test('defaults missing account type to cod', () {
      expect(
        CustomerProfileHelper.resolveAccountTypeFromMap({}),
        AppConstants.customerAccountTypeCod,
      );
    });

    test('detects contract customer helpers', () {
      final contractUser = UserModel(
        userId: '+639111111111',
        name: 'Contract User',
        phoneNumber: '+639111111111',
        customerAccountType: AppConstants.customerAccountTypeWarehouseContract,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(CustomerProfileHelper.isContractCustomer(contractUser), isTrue);
      expect(CustomerProfileHelper.shouldShowFare(contractUser), isFalse);
      expect(CustomerProfileHelper.shouldUseWallet(contractUser), isFalse);
      expect(CustomerProfileHelper.shouldShowTips(contractUser), isFalse);
    });

    test('detects cod customer helpers', () {
      final codUser = UserModel(
        userId: '+639222222222',
        name: 'COD User',
        phoneNumber: '+639222222222',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(CustomerProfileHelper.isCodCustomer(codUser), isTrue);
      expect(CustomerProfileHelper.shouldShowFare(codUser), isTrue);
      expect(CustomerProfileHelper.shouldUseWallet(codUser), isTrue);
    });
  });
}
