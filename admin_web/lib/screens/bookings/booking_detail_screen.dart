import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../services/admin_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _bookingData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    final bookingData = await AdminRepository.getNormalizedBooking(
      widget.bookingId,
    );
    if (!mounted) return;
    setState(() {
      _bookingData = bookingData;
      _loading = false;
    });
  }

  Future<void> _cancelBooking() async {
    final reasonCtrl = TextEditingController();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cancel Booking'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will cancel the booking and trigger a wallet refund if held.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation reason (required)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancel Booking'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a cancellation reason.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await AdminRepository.cancelBooking(
      bookingId: widget.bookingId,
      reason: reason,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully.')),
      );
    }
    _loadBooking();
  }

  Future<void> _addNote() async {
    final noteCtrl = TextEditingController();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Add Admin Note'),
            content: TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note text'),
              maxLines: 4,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Note'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || noteCtrl.text.trim().isEmpty) return;

    await AdminRepository.addBookingAdminNote(
      bookingId: widget.bookingId,
      note: noteCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin note added.')));
      // Refresh booking data so issueNotesCount in the header updates
      _loadBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bookingData == null) {
      return const Center(child: Text('Booking not found.'));
    }

    final d = _bookingData!;
    final status = d['status'] ?? 'unknown';
    final canCancel = ![
      'completed',
      'cancelled',
      'cancelled_by_rider',
      'cancelled_by_customer',
    ].contains(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header actions
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go('/bookings'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Bookings'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: const Text('Add Note'),
              ),
              if (canCancel) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.accent,
                  ),
                  onPressed: _cancelBooking,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Booking'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _BookingInfoCard(d: d, bookingId: widget.bookingId),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _StatusTimelineCard(d: d)),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _PaymentCard(d: d)),
              const SizedBox(width: 16),
              Expanded(child: _DemurrageCard(d: d)),
            ],
          ),
          const SizedBox(height: 16),

          _SupportNotesCard(bookingId: widget.bookingId, d: d),
          const SizedBox(height: 16),

          // Delivery photos
          if ((d['deliveryPhotos'] as List?)?.isNotEmpty == true)
            _DeliveryPhotosCard(photos: List<String>.from(d['deliveryPhotos'])),
        ],
      ),
    );
  }
}

class _BookingInfoCard extends StatelessWidget {
  final Map<String, dynamic> d;
  final String bookingId;
  const _BookingInfoCard({required this.d, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final created = AdminRepository.parseTimestamp(d['createdAt']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SectionHeader(title: 'Booking Details'),
                const SizedBox(width: 12),
                StatusBadge(d['status'] ?? 'unknown'),
              ],
            ),
            const SizedBox(height: 16),
            _Row('ID', bookingId),
            if (created != null)
              _Row(
                'Created',
                DateFormat('MMM d, yyyy – h:mm a').format(created),
              ),
            _Row('Customer', d['customerName'] ?? d['userName'] ?? '—'),
            _Row('Customer Phone', d['customerPhone'] ?? d['userPhone'] ?? '—'),
            _Row('Rider', d['riderName'] ?? '—'),
            _Row('Vehicle', d['vehicleType'] ?? d['truckType'] ?? '—'),
            const Divider(color: AdminTheme.divider),
            _Row('Pickup', d['pickupAddress'] ?? '—'),
            _Row('Dropoff', d['dropoffAddress'] ?? '—'),
            _Row('Receiver', d['receiverName'] ?? '—'),
            _Row('Receiver Phone', d['receiverPhone'] ?? '—'),
            _Row('Distance', '${d['distance'] ?? '—'} km'),
            _Row('Payment Method', d['paymentMethod'] ?? '—'),
            if ((d['cancellationReason'] ?? '').toString().isNotEmpty) ...[
              const Divider(color: AdminTheme.divider),
              _Row('Cancellation Reason', d['cancellationReason'] ?? '—'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _Row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AdminTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AdminTheme.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusTimelineCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const _StatusTimelineCard({required this.d});

  static const _timeline = [
    ('pending', 'Booking Placed', 'createdAt'),
    ('accepted', 'Accepted by Rider', 'acceptedAt'),
    ('arrived_at_pickup', 'Arrived at Pickup', 'arrivedAtPickupAt'),
    ('loading', 'Loading Started', 'loadingStartedAt'),
    ('loading_complete', 'Loading Complete', 'loadingCompletedAt'),
    ('in_transit', 'In Transit', 'inTransitAt'),
    ('arrived_at_dropoff', 'Arrived at Dropoff', 'arrivedAtDropoffAt'),
    ('unloading', 'Unloading Started', 'unloadingStartedAt'),
    ('unloading_complete', 'Unloading Complete', 'unloadingCompletedAt'),
    ('completed', 'Completed', 'completedAt'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentStatus = d['status'] ?? '';
    final statusOrder = AdminConstants.bookingStatuses;
    final currentIdx = statusOrder.indexOf(currentStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Status Timeline'),
            const SizedBox(height: 16),
            ..._timeline.map((step) {
              final (statusKey, label, tsField) = step;
              final ts = AdminRepository.parseTimestamp(d[tsField]);
              final stepIdx = statusOrder.indexOf(statusKey);
              final isDone = stepIdx >= 0 && stepIdx <= currentIdx;
              final isCurrent = statusKey == currentStatus;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? AdminTheme.primary
                              : isDone
                              ? AdminTheme.statusActive
                              : AdminTheme.divider,
                        ),
                      ),
                      if (step != _timeline.last)
                        Container(
                          width: 2,
                          height: 20,
                          color: isDone
                              ? AdminTheme.statusActive
                              : AdminTheme.divider,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isDone
                                  ? AdminTheme.textPrimary
                                  : AdminTheme.textSecondary,
                            ),
                          ),
                          if (ts != null)
                            Text(
                              DateFormat('MMM d, h:mm a').format(ts),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AdminTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const _PaymentCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final estimated = (d['estimatedFare'] ?? 0) as num;
    final final_ = (d['finalFare'] ?? 0) as num;
    final tip = (d['tipAmount'] ?? 0) as num;
    final payStatus = d['paymentStatus'] ?? '—';
    final reconciliationStatus = d['reconciliationStatus'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Payment'),
            const SizedBox(height: 12),
            _FRow('Estimated Fare', '₱ ${estimated.toStringAsFixed(2)}'),
            _FRow('Final Fare', '₱ ${final_.toStringAsFixed(2)}', bold: true),
            _FRow('Tip', '₱ ${tip.toStringAsFixed(2)}'),
            _FRow('Payment Method', d['paymentMethod'] ?? '—'),
            _FRow('Payment Status', payStatus),
            if (reconciliationStatus.toString().isNotEmpty)
              _FRow('Reconciliation', reconciliationStatus.toString()),
          ],
        ),
      ),
    );
  }

  Widget _FRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AdminTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AdminTheme.primary : AdminTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _SupportNotesCard extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> d;

  const _SupportNotesCard({required this.bookingId, required this.d});

  @override
  Widget build(BuildContext context) {
    final issueStatus = (d['issueStatus'] ?? '').toString();
    final issueNotesCount = (d['issueNotesCount'] ?? 0) as int;
    final reconciliationStatus = (d['reconciliationStatus'] ?? '').toString();
    final cancellationReason = (d['cancellationReason'] ?? '').toString();
    final cancelledAt = AdminRepository.parseTimestamp(d['cancelledAt']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SectionHeader(title: 'Issue History'),
                const SizedBox(width: 12),
                if (issueStatus.isNotEmpty) StatusBadge(issueStatus),
                if (reconciliationStatus.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  StatusBadge(reconciliationStatus),
                ],
                const Spacer(),
                Text(
                  '$issueNotesCount note${issueNotesCount == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: AdminRepository.streamBookingAdminNotes(bookingId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Error loading issue history: ${snap.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  if (cancellationReason.isEmpty) {
                    return const EmptyState(
                      message: 'No issue history yet',
                      icon: Icons.timeline_outlined,
                    );
                  }
                }

                final entries = <Map<String, dynamic>>[];
                if (cancellationReason.isNotEmpty) {
                  entries.add({
                    'title': 'Booking cancelled by admin',
                    'body': cancellationReason,
                    'type': 'flagged',
                    'createdBy': AdminConstants.adminUsername,
                    'createdAt': cancelledAt,
                  });
                }
                for (final doc in docs) {
                  final note = AdminRepository.normalizeBookingNoteData(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  );
                  entries.add({
                    'title': (note['noteType'] ?? 'support')
                        .toString()
                        .replaceAll('_', ' '),
                    'body': note['body'],
                    'type': note['noteType'] ?? 'support',
                    'createdBy': note['createdBy'],
                    'createdAt': AdminRepository.parseTimestamp(
                      note['createdAt'],
                    ),
                  });
                }
                entries.sort((a, b) {
                  final aTime = a['createdAt'] as DateTime?;
                  final bTime = b['createdAt'] as DateTime?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return Column(
                  children: entries.map((entry) {
                    final createdAt = entry['createdAt'] as DateTime?;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AdminTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x11000000),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              if (entry != entries.last)
                                Container(
                                  width: 2,
                                  height: 56,
                                  color: AdminTheme.divider,
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminTheme.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        (entry['createdBy'] ??
                                                AdminConstants.adminUsername)
                                            .toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge(
                                        (entry['type'] ?? 'support').toString(),
                                      ),
                                      const Spacer(),
                                      if (createdAt != null)
                                        Text(
                                          DateFormat(
                                            'MMM d, yyyy – h:mm a',
                                          ).format(createdAt),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: AdminTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    (entry['title'] ?? '')
                                        .toString()
                                        .toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AdminTheme.textSecondary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry['body'] ?? '',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DemurrageCard extends StatelessWidget {
  final Map<String, dynamic> d;
  const _DemurrageCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final loadingFee = (d['loadingDemurrageFee'] ?? 0) as num;
    final unloadingFee = (d['unloadingDemurrageFee'] ?? 0) as num;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Demurrage'),
            const SizedBox(height: 12),
            _FRow('Loading Started', _fmt(d['loadingStartedAt'])),
            _FRow('Loading Completed', _fmt(d['loadingCompletedAt'])),
            _FRow('Loading Fee', '₱ ${loadingFee.toStringAsFixed(2)}'),
            const Divider(color: AdminTheme.divider),
            _FRow('Unloading Started', _fmt(d['unloadingStartedAt'])),
            _FRow('Unloading Completed', _fmt(d['unloadingCompletedAt'])),
            _FRow('Unloading Fee', '₱ ${unloadingFee.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic ts) {
    final dt = AdminRepository.parseTimestamp(ts);
    return dt != null ? DateFormat('h:mm a').format(dt) : '—';
  }

  Widget _FRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AdminTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, color: AdminTheme.textPrimary),
        ),
      ],
    ),
  );
}

class _DeliveryPhotosCard extends StatelessWidget {
  final List<String> photos;
  const _DeliveryPhotosCard({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Delivery Photos'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: photos
                  .map(
                    (url) => GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: CachedNetworkImage(imageUrl: url),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 140,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
