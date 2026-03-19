import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../services/admin_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = '';
  String _issueFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filter(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty && _issueFilter == 'all') return docs;
    final q = _searchQuery.toLowerCase();
    return docs.where((d) {
      final data = AdminRepository.normalizeBookingData(
        d.id,
        d.data() as Map<String, dynamic>,
      );
      final hasIssue = (data['issueStatus'] ?? '').toString().isNotEmpty;
      final reconciliationStatus =
          (data['reconciliationStatus'] ?? '').toString();
      final matchesIssue = switch (_issueFilter) {
        'all' => true,
        'flagged' => hasIssue,
        'admin_review_required' => reconciliationStatus == 'admin_review_required',
        'clear' => !hasIssue && reconciliationStatus.isEmpty,
        _ => true,
      };
      if (!matchesIssue) return false;
      if (_searchQuery.isEmpty) return true;
      final customer = (data['customerName'] ?? data['userName'] ?? '').toString().toLowerCase();
      final rider = (data['riderName'] ?? '').toString().toLowerCase();
      final id = d.id.toLowerCase();
      return customer.contains(q) || rider.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SearchField(
                controller: _searchCtrl,
                hint: 'Search by customer, rider, ID',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _statusFilter.isEmpty ? 'all' : _statusFilter,
                  decoration: const InputDecoration(
                      labelText: 'Status', isDense: true),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    ...AdminConstants.bookingStatuses.map((s) =>
                        DropdownMenuItem(
                            value: s,
                            child: Text(s.replaceAll('_', ' ')))),
                  ],
                  onChanged: (v) => setState(
                      () => _statusFilter = v == 'all' ? '' : (v ?? '')),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _issueFilter,
                  decoration: const InputDecoration(
                    labelText: 'Issue State',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All issues')),
                    DropdownMenuItem(value: 'flagged', child: Text('Flagged')),
                    DropdownMenuItem(
                      value: 'admin_review_required',
                      child: Text('Needs reconciliation'),
                    ),
                    DropdownMenuItem(value: 'clear', child: Text('Clear')),
                  ],
                  onChanged: (v) => setState(() => _issueFilter = v ?? 'all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AdminRepository.streamBookings(
                statusFilter:
                    _statusFilter.isEmpty ? null : _statusFilter,
                limit: 200,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = _filter(snap.data?.docs ?? []);
                if (docs.isEmpty) {
                  return const EmptyState(
                      message: 'No bookings found',
                      icon: Icons.receipt_long_outlined);
                }
                return Card(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminTheme.divider),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = AdminRepository.normalizeBookingData(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      );
                      final status = d['status'] ?? 'unknown';
                      final customer = d['customerName'] ?? d['userName'] ?? '—';
                      final rider = d['riderName'] ?? '—';
                      final fare = (d['finalFare'] ?? d['estimatedFare'] ?? 0);
                        final issueStatus = (d['issueStatus'] ?? '').toString();
                        final noteCount = (d['issueNotesCount'] ?? 0) as int;
                        final reconciliationStatus =
                          (d['reconciliationStatus'] ?? '').toString();
                      final ts = AdminRepository.parseTimestamp(d['createdAt']);
                      final shortId = doc.id.length > 8
                          ? doc.id.substring(0, 8)
                          : doc.id;

                      return ListTile(
                        leading: StatusBadge(status),
                        title: Text(
                          '${d['pickupAddress'] ?? 'Pickup'} → ${d['dropoffAddress'] ?? 'Dropoff'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '#$shortId  ·  $customer  →  $rider'
                          '${ts != null ? '  ·  ${DateFormat('MMM d, h:mm a').format(ts)}' : ''}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminTheme.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (issueStatus.isNotEmpty) ...[
                              StatusBadge(issueStatus),
                              const SizedBox(width: 6),
                            ],
                            if (reconciliationStatus.isNotEmpty) ...[
                              StatusBadge(reconciliationStatus),
                              const SizedBox(width: 6),
                            ],
                            if (noteCount > 0) ...[
                              Text(
                                '$noteCount',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text('₱ $fare',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AdminTheme.primary)),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right,
                                color: AdminTheme.textSecondary),
                          ],
                        ),
                        onTap: () => context.go('/bookings/${doc.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
