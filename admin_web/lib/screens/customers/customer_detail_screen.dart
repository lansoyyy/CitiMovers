import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userData = await AdminRepository.getNormalizedUser(widget.customerId);
    if (!mounted) return;
    setState(() {
      _userData = userData;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleSuspend() async {
    final isSuspended = _userData?['isSuspended'] == true;
    final action = isSuspended ? 'Reactivate' : 'Suspend';
    final confirmed = await ConfirmDialog.show(
      context,
      title: '$action Customer',
      message: 'Are you sure you want to $action this customer account?',
      confirmLabel: action,
      confirmColor: isSuspended ? AdminTheme.statusActive : AdminTheme.accent,
    );
    if (!confirmed) return;

    final newValue = !isSuspended;
    await AdminRepository.setUserSuspended(
      userId: widget.customerId,
      isSuspended: newValue,
    );
    _loadUser();
  }

  Future<void> _adjustWallet() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Manual Wallet Adjustment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (use negative to deduct)',
                    prefixText: '₱ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Reason (required)'),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Apply')),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || reasonCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid amount or missing reason.')));
      }
      return;
    }

    final currentBalance =
        ((_userData?['walletBalance'] ?? 0) as num).toDouble();
    await AdminRepository.adjustUserWallet(
      userId: widget.customerId,
      amount: amount,
      reason: reasonCtrl.text.trim(),
    );

    if (mounted) {
      final newBalance = currentBalance + amount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wallet updated to ₱ ${newBalance.toStringAsFixed(2)}',
          ),
        ),
      );
    }
    _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_userData == null) {
      return const Center(child: Text('Customer not found.'));
    }

    final d = _userData!;
    final name = d['name'] ?? 'Unknown';
    final phone = d['phoneNumber'] ?? '';
    final email = d['email'] ?? '';
    final balance =
        ((d['walletBalance'] ?? 0) as num).toDouble();
    final isSuspended = d['isSuspended'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + actions
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go('/customers'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Customers'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _adjustWallet,
                icon: const Icon(Icons.account_balance_wallet, size: 16),
                label: const Text('Adjust Wallet'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSuspended ? AdminTheme.statusActive : AdminTheme.accent,
                ),
                onPressed: _toggleSuspend,
                icon: Icon(
                    isSuspended ? Icons.check_circle : Icons.block,
                    size: 16),
                label: Text(isSuspended ? 'Reactivate' : 'Suspend'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AdminTheme.primary.withOpacity(0.1),
                    child: Text(
                      (name as String).isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name,
                                style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            StatusBadge(
                                isSuspended ? 'suspended' : 'active'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('$phone  ·  $email',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AdminTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Wallet: ₱ ${balance.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AdminTheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tabs
          Card(
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
                    Tab(text: 'Booking History'),
                    Tab(text: 'Wallet Transactions'),
                    Tab(text: 'Saved Locations'),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _BookingHistoryTab(customerId: widget.customerId),
                      _WalletTab(userId: widget.customerId),
                      _SavedLocationsTab(userId: widget.customerId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking History Tab ──────────────────────────────────────────────────────
class _BookingHistoryTab extends StatelessWidget {
  final String customerId;
  const _BookingHistoryTab({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamCustomerBookings(customerId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
              message: 'No bookings', icon: Icons.receipt_long_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = AdminRepository.normalizeBookingData(
              docs[i].id,
              docs[i].data() as Map<String, dynamic>,
            );
            final fare =
                (d['finalFare'] ?? d['estimatedFare'] ?? 0).toString();
            final status = d['status'] ?? 'unknown';
            final ts = AdminRepository.parseTimestamp(d['createdAt']);
            return ListTile(
              dense: true,
              leading: StatusBadge(status),
              title: Text(
                  '${d['pickupAddress'] ?? 'Pickup'} → ${d['dropoffAddress'] ?? 'Dropoff'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12)),
              subtitle: ts != null
                  ? Text(DateFormat('MMM d, yyyy – h:mm a').format(ts),
                      style: GoogleFonts.inter(fontSize: 11))
                  : null,
              trailing: Text('₱ $fare',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              onTap: () => context.go('/bookings/${docs[i].id}'),
            );
          },
        );
      },
    );
  }
}

// ─── Wallet Transactions Tab ──────────────────────────────────────────────────
class _WalletTab extends StatelessWidget {
  final String userId;
  const _WalletTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamWalletTransactions(userId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
              message: 'No wallet transactions',
              icon: Icons.account_balance_wallet_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final amount = (d['amount'] ?? 0) as num;
            final type = d['type'] ?? d['transactionType'] ?? 'transaction';
            final desc = d['description'] ?? d['remarks'] ?? '';
            final ts = AdminRepository.parseTimestamp(d['createdAt']);
            return ListTile(
              dense: true,
              leading: Icon(
                amount >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: amount >= 0 ? AdminTheme.statusActive : AdminTheme.accent,
              ),
              title: Text(type.toString().replaceAll('_', ' '),
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              subtitle: desc.isNotEmpty
                  ? Text(desc, style: GoogleFonts.inter(fontSize: 11))
                  : null,
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
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

// ─── Saved Locations Tab ──────────────────────────────────────────────────────
class _SavedLocationsTab extends StatelessWidget {
  final String userId;
  const _SavedLocationsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamSavedLocations(userId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
              message: 'No saved locations',
              icon: Icons.location_on_outlined);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined,
                  color: AdminTheme.primary),
              title: Text(d['label'] ?? d['name'] ?? 'Location',
                  style: GoogleFonts.inter(fontSize: 13)),
              subtitle: Text(d['address'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AdminTheme.textSecondary)),
            );
          },
        );
      },
    );
  }
}
