import 'package:admin_web/services/export_account_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ExportAccountProfile maps user fields to account columns', () {
    final profile = ExportAccountProfile.fromUser({
      'id': 'user-1',
      'userId': 'user-1',
      'name': 'Juan Dela Cruz',
      'phoneNumber': '+639171234567',
      'email': 'juan@example.com',
      'accountStatus': 'active',
    });

    expect(profile.accountType, 'Customer');
    expect(profile.accountName, 'Juan Dela Cruz');
    expect(
      AdminExportAccountResolver.accountColumns(profile),
      ['Customer', 'Juan Dela Cruz', '+639171234567', 'juan@example.com', 'active'],
    );
  });

  test('ExportAccountProfile maps rider fields to account columns', () {
    final profile = ExportAccountProfile.fromRider({
      'id': 'rider-9',
      'riderId': 'rider-9',
      'name': 'Rider One',
      'phoneNumber': '+639189999999',
      'accountStatus': 'active',
    });

    expect(profile.accountType, 'Rider');
    expect(profile.accountName, 'Rider One');
  });

  test('buildWalletAccountSummaryRows aggregates per account', () {
    final profiles = {
      'user-1': ExportAccountProfile.fromUser({
        'id': 'user-1',
        'userId': 'user-1',
        'name': 'Juan',
        'phoneNumber': '+63917',
        'accountStatus': 'active',
      }),
    };

    final summary = AdminExportAccountResolver.buildWalletAccountSummaryRows(
      transactions: [
        {'userId': 'user-1', 'amount': 100},
        {'userId': 'user-1', 'amount': -25},
        {'userId': 'rider-2', 'amount': 50},
      ],
      accounts: profiles,
    );

    expect(summary.first, isEmpty);
    expect(summary[1].first, 'ACCOUNT SUMMARY');
    expect(summary.any((row) => row.contains('Juan')), isTrue);
    expect(summary.any((row) => row.contains('75.00')), isTrue);
  });
}
