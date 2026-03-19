import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalUsers = 0;
  int _pendingRiderApprovals = 0;
  Map<String, int> _bookingCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final results = await Future.wait([
      AdminRepository.countUsers(),
      AdminRepository.countPendingRiderApprovals(),
      AdminRepository.getBookingStatusCounts(),
    ]);
    if (!mounted) return;
    setState(() {
      _totalUsers = results[0] as int;
      _pendingRiderApprovals = results[1] as int;
      _bookingCounts = results[2] as Map<String, int>;
      _loading = false;
    });
  }

  int get _activeBookings {
    const active = [
      'accepted',
      'arrived_at_pickup',
      'loading',
      'loading_complete',
      'in_transit',
      'arrived_at_dropoff',
      'unloading',
      'unloading_complete',
    ];
    return active.fold(0, (s, k) => s + (_bookingCounts[k] ?? 0));
  }

  int get _completedBookings => _bookingCounts['completed'] ?? 0;
  int get _cancelledBookings =>
      (_bookingCounts['cancelled'] ?? 0) +
      (_bookingCounts['cancelled_by_rider'] ?? 0);
  int get _totalBookings => _bookingCounts.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          _buildKpiRow(),
          const SizedBox(height: 24),

          // Charts + Recent
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _BookingStatusChart(counts: _bookingCounts),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _PendingApprovalsList()),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Bookings
          _RecentBookingsTable(),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 4 : 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: (constraints.maxWidth - (cols - 1) * 16) / cols,
              child: StatCard(
                label: 'Total Customers',
                value: _totalUsers.toString(),
                icon: Icons.people_outlined,
                iconColor: AdminTheme.primary,
                onTap: () => context.go('/customers'),
              ),
            ),
            SizedBox(
              width: (constraints.maxWidth - (cols - 1) * 16) / cols,
              child: StatCard(
                label: 'Active Bookings',
                value: _activeBookings.toString(),
                icon: Icons.local_shipping_outlined,
                iconColor: AdminTheme.statusActive,
                iconBg: AdminTheme.statusActive,
                onTap: () => context.go('/bookings'),
              ),
            ),
            SizedBox(
              width: (constraints.maxWidth - (cols - 1) * 16) / cols,
              child: StatCard(
                label: 'Pending Approvals',
                value: _pendingRiderApprovals.toString(),
                icon: Icons.pending_actions_outlined,
                iconColor: AdminTheme.statusPending,
                iconBg: AdminTheme.statusPending,
                subtitle: 'Rider documents awaiting review',
                onTap: () => context.go('/riders'),
              ),
            ),
            SizedBox(
              width: (constraints.maxWidth - (cols - 1) * 16) / cols,
              child: StatCard(
                label: 'Total Bookings',
                value: _totalBookings.toString(),
                icon: Icons.receipt_long_outlined,
                iconColor: AdminTheme.statusCompleted,
                iconBg: AdminTheme.statusCompleted,
                subtitle:
                    '$_completedBookings completed · $_cancelledBookings cancelled',
                onTap: () => context.go('/bookings'),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Booking Status Donut Chart ──────────────────────────────────────────────
class _BookingStatusChart extends StatelessWidget {
  final Map<String, int> counts;
  const _BookingStatusChart({required this.counts});

  static const _colorMap = {
    'pending': AdminTheme.statusPending,
    'accepted': AdminTheme.primary,
    'in_transit': AdminTheme.statusCompleted,
    'completed': AdminTheme.statusActive,
    'cancelled': AdminTheme.statusCancelled,
    'cancelled_by_rider': AdminTheme.statusWarning,
  };

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Card(
        child: SizedBox(
          height: 240,
          child: EmptyState(
            message: 'No booking data yet',
            icon: Icons.pie_chart_outline,
          ),
        ),
      );
    }

    final sections = entries.map((e) {
      final color = _colorMap[e.key] ?? AdminTheme.textSecondary;
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        radius: 60,
        title: e.value.toString(),
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Booking Status Distribution'),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.map((e) {
                      final color =
                          _colorMap[e.key] ?? AdminTheme.textSecondary;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              e.key.replaceAll('_', ' '),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AdminTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pending Rider Approvals ──────────────────────────────────────────────────
class _PendingApprovalsList extends StatelessWidget {
  const _PendingApprovalsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamRiders(statusFilter: 'pending'),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Pending Approvals',
                  trailing: TextButton(
                    onPressed: () => context.go('/riders'),
                    child: const Text('View all'),
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No pending rider approvals',
                        style: TextStyle(color: AdminTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ...docs.take(5).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown Rider';
                    final phone = data['phoneNumber'] ?? '';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AdminTheme.primary.withOpacity(0.1),
                        child: Text(
                          (name as String).isNotEmpty
                              ? name[0].toUpperCase()
                              : 'R',
                          style: GoogleFonts.inter(
                            color: AdminTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        phone,
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      trailing: TextButton(
                        onPressed: () => context.go('/riders/${doc.id}'),
                        child: const Text('Review'),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Recent Bookings Table ────────────────────────────────────────────────────
class _RecentBookingsTable extends StatelessWidget {
  const _RecentBookingsTable();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamBookings(limit: 8),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Recent Bookings',
                  trailing: TextButton(
                    onPressed: () => context.go('/bookings'),
                    child: const Text('View all'),
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const EmptyState(
                    message: 'No bookings yet',
                    icon: Icons.receipt_long_outlined,
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AdminTheme.divider),
                          ),
                        ),
                        children:
                            [
                                  'Booking ID',
                                  'Customer',
                                  'Rider',
                                  'Status',
                                  'Amount',
                                ]
                                .map(
                                  (h) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      h,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AdminTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      ...docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final fare = (d['estimatedFare'] ?? d['finalFare'] ?? 0)
                            .toString();
                        final id = doc.id;
                        final shortId = id.length > 8 ? id.substring(0, 8) : id;
                        return TableRow(
                          children: [
                            _cell(
                              TextButton(
                                onPressed: () => context.go('/bookings/$id'),
                                child: Text(
                                  '#$shortId...',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AdminTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            _cell(
                              Text(
                                d['customerName'] ?? d['userName'] ?? '—',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                            _cell(
                              Text(
                                d['riderName'] ?? '—',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                            _cell(StatusBadge(d['status'] ?? 'unknown')),
                            _cell(
                              Text(
                                '₱ $fare',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: child,
  );
}
