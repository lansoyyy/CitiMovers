import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              labelColor: AdminTheme.primary,
              unselectedLabelColor: AdminTheme.textSecondary,
              indicatorColor: AdminTheme.primary,
              labelStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600),
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
              icon: Icons.payments_outlined);
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
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking: ${d['bookingId'] ?? '—'}',
                      style:
                          GoogleFonts.inter(fontSize: 11)),
                  if (ts != null)
                    Text(DateFormat('MMM d, yyyy – h:mm a').format(ts),
                        style: GoogleFonts.inter(fontSize: 10)),
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
              icon: Icons.account_balance_wallet_outlined);
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
                color: amount >= 0 ? AdminTheme.statusActive : AdminTheme.accent,
                size: 18,
              ),
              title: Text(type,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              subtitle: Text(userId,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AdminTheme.textSecondary)),
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
                            : AdminTheme.accent),
                  ),
                  if (ts != null)
                    Text(DateFormat('MMM d').format(ts),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AdminTheme.textSecondary)),
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
            final reconciliationStatus =
                (d['reconciliationStatus'] ?? '').toString();
            final shortId = docs[i].id.length > 8
                ? docs[i].id.substring(0, 8)
                : docs[i].id;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Row(
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
                  StatusBadge(reconciliationStatus),
                  if (issueStatus.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    StatusBadge(issueStatus),
                  ],
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              trailing: Wrap(
                spacing: 8,
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
                  IconButton(
                    onPressed: () => context.go('/bookings/${docs[i].id}'),
                    icon: const Icon(Icons.open_in_new_outlined),
                    tooltip: 'Open booking',
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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason / note',
              ),
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
