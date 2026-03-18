import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _tabs = TabController(length: 2, vsync: this);
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
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PaymentsTab(),
                  _WalletLedgerTab(),
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
            final d = docs[i].data() as Map<String, dynamic>;
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
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
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
            final d = docs[i].data() as Map<String, dynamic>;
            // normalize dual-schema: 'amount' or 'balance' field
            final amount = (d['amount'] ?? d['balance'] ?? d['newBalance'] ?? 0) as num;
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
