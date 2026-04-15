import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../services/csv_export_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<int> _exportPayments() async {
    final payments = await AdminRepository.getPayments(limit: 500);
    if (payments.isEmpty) {
      throw StateError('No payment records available to export.');
    }

    final rows = payments.map((payment) {
      final createdAt = AdminRepository.parseTimestamp(payment['createdAt']);
      final amount = (payment['amount'] ?? 0) as num;

      return <String>[
        (payment['id'] ?? '').toString(),
        (payment['bookingId'] ?? '').toString(),
        (payment['paymentMethod'] ?? payment['method'] ?? '').toString(),
        (payment['paymentStatus'] ?? payment['status'] ?? '').toString(),
        amount.toStringAsFixed(2),
        (payment['reconciliationStatus'] ?? '').toString(),
        createdAt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt)
            : '',
      ];
    }).toList();

    AdminCsvExportService.downloadCsv(
      fileName:
          'payments_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      headers: const [
        'Payment ID',
        'Booking ID',
        'Method',
        'Status',
        'Amount',
        'Reconciliation Status',
        'Created At',
      ],
      rows: rows,
    );

    return rows.length;
  }

  Future<int> _exportWalletLedger() async {
    final transactions = await AdminRepository.getWalletTransactions(
      limit: 500,
    );
    if (transactions.isEmpty) {
      throw StateError('No wallet transactions available to export.');
    }

    final rows = transactions.map((transaction) {
      final createdAt = AdminRepository.parseTimestamp(
        transaction['createdAt'],
      );
      final amount = (transaction['amount'] ?? 0) as num;
      final balance =
          (transaction['newBalance'] ?? transaction['balance'] ?? 0) as num;

      return <String>[
        (transaction['id'] ?? '').toString(),
        (transaction['userId'] ?? '').toString(),
        (transaction['type'] ?? transaction['transactionType'] ?? '')
            .toString(),
        amount.toStringAsFixed(2),
        balance.toStringAsFixed(2),
        (transaction['description'] ?? transaction['remarks'] ?? '').toString(),
        createdAt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt)
            : '',
      ];
    }).toList();

    AdminCsvExportService.downloadCsv(
      fileName:
          'wallet_ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      headers: const [
        'Transaction ID',
        'User ID',
        'Type',
        'Amount',
        'Balance',
        'Description',
        'Created At',
      ],
      rows: rows,
    );

    return rows.length;
  }

  Future<int> _exportReconciliationQueue() async {
    final bookings = await AdminRepository.getReconciliationQueue(limit: 500);
    if (bookings.isEmpty) {
      throw StateError('No reconciliation records available to export.');
    }

    final rows = bookings.map((booking) {
      final createdAt = AdminRepository.parseTimestamp(booking['createdAt']);
      final fare =
          (booking['finalFare'] ?? booking['estimatedFare'] ?? 0) as num;

      return <String>[
        (booking['tripNumber'] ?? '').toString(),
        (booking['bookingId'] ?? '').toString(),
        (booking['customerName'] ?? '').toString(),
        (booking['status'] ?? '').toString(),
        (booking['paymentStatus'] ?? '').toString(),
        (booking['reconciliationStatus'] ?? '').toString(),
        fare.toStringAsFixed(2),
        (booking['pickupAddress'] ?? '').toString(),
        (booking['dropoffAddress'] ?? '').toString(),
        createdAt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt)
            : '',
      ];
    }).toList();

    AdminCsvExportService.downloadCsv(
      fileName:
          'reconciliation_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      headers: const [
        'Trip Ticket',
        'Booking ID',
        'Customer',
        'Status',
        'Payment Status',
        'Reconciliation Status',
        'Fare',
        'Pickup',
        'Dropoff',
        'Created At',
      ],
      rows: rows,
    );

    return rows.length;
  }

  Future<void> _exportCurrentTab() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      String label;
      int count;
      switch (_tabs.index) {
        case 0:
          label = 'payments';
          count = await _exportPayments();
          break;
        case 1:
          label = 'wallet ledger';
          count = await _exportWalletLedger();
          break;
        default:
          label = 'reconciliation queue';
          count = await _exportReconciliationQueue();
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $count $label rows to CSV.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finance export failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final exportButton = OutlinedButton.icon(
                onPressed: _exporting ? null : _exportCurrentTab,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 16),
                label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
              );

              final helperText = Text(
                'Download the current finance tab as CSV for Excel.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
              );

              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    helperText,
                    const SizedBox(height: 12),
                    exportButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: helperText),
                  exportButton,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    labelColor: AdminTheme.primary,
                    unselectedLabelColor: AdminTheme.textSecondary,
                    indicatorColor: AdminTheme.primary,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Payment Transactions'),
                      Tab(text: 'Wallet Ledger'),
                      Tab(text: 'Reconciliation Queue'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _PaymentsTab(),
                        _WalletLedgerTab(),
                        _ReconciliationQueueTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamPayments(limit: 100),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No payment records',
            icon: Icons.payments_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = AdminRepository.normalizePaymentData(
              docs[i].id,
              docs[i].data() as Map<String, dynamic>,
            );
            final amount = (d['amount'] ?? 0) as num;
            final status = d['status'] ?? d['paymentStatus'] ?? '—';
            final method = d['method'] ?? d['paymentMethod'] ?? '—';
            final ts = AdminRepository.parseTimestamp(d['createdAt']);
            return ListTile(
              dense: true,
              leading: StatusBadge(status.toString()),
              title: Text(
                '$method  ·  ₱ ${amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking: ${d['bookingId'] ?? '—'}',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  if (ts != null)
                    Text(
                      DateFormat('MMM d, yyyy – h:mm a').format(ts),
                      style: GoogleFonts.inter(fontSize: 10),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WalletLedgerTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamAllWalletTransactions(limit: 100),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No wallet transactions',
            icon: Icons.account_balance_wallet_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = AdminRepository.normalizeWalletTransactionData(
              docs[i].id,
              docs[i].data() as Map<String, dynamic>,
            );
            final amount = (d['amount'] ?? 0) as num;
            final type = (d['type'] ?? d['transactionType'] ?? 'transaction')
                .toString()
                .replaceAll('_', ' ');
            final userId = d['userId'] ?? d['riderId'] ?? '—';
            final ts = AdminRepository.parseTimestamp(d['createdAt']);
            return ListTile(
              dense: true,
              leading: Icon(
                amount >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: amount >= 0
                    ? AdminTheme.statusActive
                    : AdminTheme.accent,
                size: 18,
              ),
              title: Text(
                type,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                userId,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AdminTheme.textSecondary,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${amount >= 0 ? '+' : ''}₱ ${amount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: amount >= 0
                          ? AdminTheme.statusActive
                          : AdminTheme.accent,
                    ),
                  ),
                  if (ts != null)
                    Text(
                      DateFormat('MMM d').format(ts),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReconciliationQueueTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamReconciliationQueue(limit: 100),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No reconciliation items pending',
            icon: Icons.fact_check_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = AdminRepository.normalizeBookingData(
              docs[i].id,
              docs[i].data() as Map<String, dynamic>,
            );
            final amount = (d['finalFare'] ?? d['estimatedFare'] ?? 0) as num;
            final createdAt = AdminRepository.parseTimestamp(d['createdAt']);
            final issueStatus = (d['issueStatus'] ?? '').toString();
            final reconciliationStatus = (d['reconciliationStatus'] ?? '')
                .toString();
            final shortId = docs[i].id.length > 8
                ? docs[i].id.substring(0, 8)
                : docs[i].id;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final badges = <Widget>[
                        StatusBadge(reconciliationStatus),
                        if (issueStatus.isNotEmpty) StatusBadge(issueStatus),
                      ];

                      if (constraints.maxWidth < 760) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#$shortId · ${d['customerName'] ?? 'Unknown Customer'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: badges),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '#$shortId · ${d['customerName'] ?? 'Unknown Customer'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: badges),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${d['pickupAddress'] ?? 'Pickup'} → ${d['dropoffAddress'] ?? 'Dropoff'}',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payment: ${d['paymentStatus'] ?? '—'} · Fare: ₱ ${amount.toStringAsFixed(2)}${createdAt != null ? ' · ${DateFormat('MMM d, h:mm a').format(createdAt)}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _updateReconciliation(
                          context,
                          bookingId: docs[i].id,
                          status: 'under_review',
                          label: 'Mark Under Review',
                        ),
                        child: const Text('Under Review'),
                      ),
                      ElevatedButton(
                        onPressed: () => _updateReconciliation(
                          context,
                          bookingId: docs[i].id,
                          status: 'reconciled',
                          label: 'Mark Reconciled',
                        ),
                        child: const Text('Reconciled'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/bookings/${docs[i].id}'),
                        icon: const Icon(Icons.open_in_new_outlined, size: 16),
                        label: const Text('Open Booking'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateReconciliation(
    BuildContext context, {
    required String bookingId,
    required String status,
    required String label,
  }) async {
    final reasonCtrl = TextEditingController();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason / note'),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(label),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || reasonCtrl.text.trim().isEmpty) return;

    await AdminRepository.updateBookingReconciliationStatus(
      bookingId: bookingId,
      status: status,
      reason: reasonCtrl.text.trim(),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated booking reconciliation to $status.')),
      );
    }
  }
}
