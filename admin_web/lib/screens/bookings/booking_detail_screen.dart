import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../services/admin_repository.dart';
import '../../services/audit_service.dart';
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
    final doc = await AdminRepository.getBooking(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _bookingData = doc.exists ? doc.data() as Map<String, dynamic> : null;
      _loading = false;
    });
  }

  Future<void> _cancelBooking() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cancel Booking'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'This will cancel the booking and trigger a wallet refund if held.'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Cancellation reason (required)'),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Back')),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AdminTheme.accent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancel Booking'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || reasonCtrl.text.trim().isEmpty) return;

    await AdminRepository.updateBooking(widget.bookingId, {
      'status': 'cancelled',
      'cancellationReason': reasonCtrl.text.trim(),
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': 'admin',
    });
    await AdminAuditService.log(
      action: AdminConstants.auditCancelBooking,
      entityType: 'booking',
      entityId: widget.bookingId,
      reason: reasonCtrl.text.trim(),
      before: {'status': _bookingData?['status']},
      after: {'status': 'cancelled'},
    );
    _loadBooking();
  }

  Future<void> _addNote() async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Add Admin Note'),
            content: TextField(
              controller: noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Note text'),
              maxLines: 4,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add Note')),
            ],
          ),
        ) ??
        false;

    if (!confirmed || noteCtrl.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection(AdminConstants.colBookings)
        .doc(widget.bookingId)
        .collection('admin_notes')
        .add({
      'note': noteCtrl.text.trim(),
      'addedBy': AdminConstants.adminUsername,
      'addedAt': FieldValue.serverTimestamp(),
    });
    await AdminAuditService.log(
      action: AdminConstants.auditAddBookingNote,
      entityType: 'booking',
      entityId: widget.bookingId,
      reason: noteCtrl.text.trim(),
    );
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
    final canCancel = !['completed', 'cancelled', 'cancelled_by_rider']
        .contains(status);

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
                      backgroundColor: AdminTheme.accent),
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
              Expanded(flex: 5, child: _BookingInfoCard(d: d, bookingId: widget.bookingId)),
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
              _Row('Created', DateFormat('MMM d, yyyy – h:mm a').format(created)),
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
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AdminTheme.textPrimary)),
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
                                : AdminTheme.divider),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isDone
                                      ? AdminTheme.textPrimary
                                      : AdminTheme.textSecondary)),
                          if (ts != null)
                            Text(
                                DateFormat('MMM d, h:mm a').format(ts),
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AdminTheme.textSecondary)),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Payment'),
            const SizedBox(height: 12),
            _FRow('Estimated Fare', '₱ ${estimated.toStringAsFixed(2)}'),
            _FRow('Final Fare', '₱ ${final_.toStringAsFixed(2)}',
                bold: true),
            _FRow('Tip', '₱ ${tip.toStringAsFixed(2)}'),
            _FRow('Payment Method', d['paymentMethod'] ?? '—'),
            _FRow('Payment Status', payStatus),
          ],
        ),
      ),
    );
  }

  Widget _FRow(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AdminTheme.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold ? AdminTheme.primary : AdminTheme.textPrimary)),
        ]),
      );
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
            _FRow('Loading Started',
                _fmt(d['loadingStartedAt'])),
            _FRow('Loading Completed',
                _fmt(d['loadingCompletedAt'])),
            _FRow('Loading Fee',
                '₱ ${loadingFee.toStringAsFixed(2)}'),
            const Divider(color: AdminTheme.divider),
            _FRow('Unloading Started',
                _fmt(d['unloadingStartedAt'])),
            _FRow('Unloading Completed',
                _fmt(d['unloadingCompletedAt'])),
            _FRow('Unloading Fee',
                '₱ ${unloadingFee.toStringAsFixed(2)}'),
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
        child: Row(children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AdminTheme.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AdminTheme.textPrimary)),
        ]),
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
              children: photos.map((url) => GestureDetector(
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
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
