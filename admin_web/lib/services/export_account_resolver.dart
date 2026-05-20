import 'admin_repository.dart';

class ExportAccountProfile {
  final String accountId;
  final String accountType;
  final String accountName;
  final String accountPhone;
  final String accountEmail;
  final String accountStatus;

  const ExportAccountProfile({
    required this.accountId,
    required this.accountType,
    required this.accountName,
    required this.accountPhone,
    required this.accountEmail,
    required this.accountStatus,
  });

  factory ExportAccountProfile.fromUser(Map<String, dynamic> user) {
    return ExportAccountProfile(
      accountId: user['userId']?.toString() ?? user['id']?.toString() ?? '',
      accountType: 'Customer',
      accountName: user['name']?.toString() ?? 'Unknown',
      accountPhone: user['phoneNumber']?.toString() ?? '',
      accountEmail: user['email']?.toString() ?? '',
      accountStatus: user['accountStatus']?.toString() ?? 'active',
    );
  }

  factory ExportAccountProfile.fromRider(Map<String, dynamic> rider) {
    return ExportAccountProfile(
      accountId: rider['riderId']?.toString() ?? rider['id']?.toString() ?? '',
      accountType: 'Rider',
      accountName: rider['name']?.toString() ?? 'Unknown Rider',
      accountPhone: rider['phoneNumber']?.toString() ?? '',
      accountEmail: rider['email']?.toString() ?? '',
      accountStatus: rider['accountStatus']?.toString() ?? 'pending',
    );
  }

  factory ExportAccountProfile.unknown(String accountId) {
    return ExportAccountProfile(
      accountId: accountId,
      accountType: 'Unknown',
      accountName: 'Unknown Account',
      accountPhone: '',
      accountEmail: '',
      accountStatus: '',
    );
  }
}

class AdminExportAccountResolver {
  static const int _chunkSize = 30;

  static Future<Map<String, ExportAccountProfile>> resolveProfiles(
    Iterable<String> rawIds,
  ) async {
    final ids = rawIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return {};

    final profiles = <String, ExportAccountProfile>{};
    final idList = ids.toList();

    for (var offset = 0; offset < idList.length; offset += _chunkSize) {
      final chunk = idList.skip(offset).take(_chunkSize);
      final entries = await Future.wait(
        chunk.map((id) async {
          final user = await AdminRepository.getNormalizedUser(id);
          if (user != null) {
            return MapEntry(id, ExportAccountProfile.fromUser(user));
          }

          final rider = await AdminRepository.getNormalizedRider(id);
          if (rider != null) {
            return MapEntry(id, ExportAccountProfile.fromRider(rider));
          }

          return MapEntry(id, ExportAccountProfile.unknown(id));
        }),
      );
      profiles.addEntries(entries);
    }

    return profiles;
  }

  static List<String> accountColumns(ExportAccountProfile profile) {
    return [
      profile.accountType,
      profile.accountName,
      profile.accountPhone,
      profile.accountEmail,
      profile.accountStatus,
    ];
  }

  static const accountHeaders = [
    'Account Type',
    'Account Name',
    'Account Phone',
    'Account Email',
    'Account Status',
  ];

  /// Appends per-account totals after transaction rows in a wallet ledger export.
  static List<List<String>> buildWalletAccountSummaryRows({
    required List<Map<String, dynamic>> transactions,
    required Map<String, ExportAccountProfile> accounts,
  }) {
    final totals = <String, ({int count, double netAmount})>{};

    for (final transaction in transactions) {
      final userId = (transaction['userId'] ?? '').toString();
      if (userId.isEmpty) continue;

      final amount = (transaction['amount'] ?? 0) as num;
      final current = totals[userId];
      totals[userId] = (
        count: (current?.count ?? 0) + 1,
        netAmount: (current?.netAmount ?? 0) + amount.toDouble(),
      );
    }

    if (totals.isEmpty) return const [];

    final summaryRows = <List<String>>[
      const [],
      const [
        'ACCOUNT SUMMARY',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        'Account Type',
        'Account Name',
        'Account Phone',
        'User ID',
        'Transaction Count',
        'Net Amount',
        '',
        '',
        '',
        '',
        '',
      ],
    ];

    final sortedEntries = totals.entries.toList()
      ..sort((a, b) {
        final aName =
            accounts[a.key]?.accountName ?? ExportAccountProfile.unknown(a.key).accountName;
        final bName =
            accounts[b.key]?.accountName ?? ExportAccountProfile.unknown(b.key).accountName;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

    for (final entry in sortedEntries) {
      final profile =
          accounts[entry.key] ?? ExportAccountProfile.unknown(entry.key);
      summaryRows.add([
        profile.accountType,
        profile.accountName,
        profile.accountPhone,
        entry.key,
        entry.value.count.toString(),
        entry.value.netAmount.toStringAsFixed(2),
        '',
        '',
        '',
        '',
        '',
      ]);
    }

    return summaryRows;
  }
}
