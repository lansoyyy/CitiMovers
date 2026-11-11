import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../services/admin_repository.dart';
import '../../utils/rider_booking_capacity.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _RiderAssignmentDialogResult {
  final String riderId;
  final String reason;

  const _RiderAssignmentDialogResult({
    required this.riderId,
    required this.reason,
  });
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _bookingData;
  bool _loading = true;
  bool _isMutating = false;
  String? _loadError;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSub;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _subscribeToBooking();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  /// Live subscription so rider-side updates (arrivals, loading, unloading,
  /// completion) appear immediately while the admin has this page open.
  void _subscribeToBooking() {
    _bookingSub?.cancel();
    _bookingSub = AdminRepository.streamBooking(widget.bookingId).listen(
      (snap) {
        if (!mounted || !snap.exists) return;
        setState(() {
          _bookingData = AdminRepository.normalizeBookingData(
            widget.bookingId,
            _asMap(snap.data()),
          );
          _loading = false;
          _loadError = null;
        });
      },
      onError: (error) {
        debugPrint('Booking stream error: $error');
      },
    );
  }

  Future<void> _loadBooking() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final bookingData = await AdminRepository.getNormalizedBooking(
        widget.bookingId,
      );
      if (!mounted) return;
      setState(() {
        _bookingData = bookingData;
        _loading = false;
        _loadError = bookingData == null ? 'Booking not found.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _cancelBooking() async {
    if (_isMutating) return;

    final status = (_bookingData?['status'] ?? '').toString();
    final paymentStatus = (_bookingData?['paymentStatus'] ?? '').toString();
    const lateCancellationStatuses = [
      'arrived_at_pickup',
      'loading',
      'loading_complete',
      'in_transit',
      'arrived_at_dropoff',
      'unloading',
      'unloading_complete',
    ];
    final capturesHeldAmount =
        paymentStatus == 'held' && lateCancellationStatuses.contains(status);
    final willRefund = paymentStatus == 'held' && !capturesHeldAmount;
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? reasonError;
        final viewportWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth = viewportWidth > 560 ? 420.0 : viewportWidth * 0.82;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Cancel Booking'),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capturesHeldAmount
                        ? 'This will cancel the booking and keep the original held booking amount as the cancellation charge.'
                        : willRefund
                        ? 'This will cancel the booking and refund the held amount to the customer wallet.'
                        : 'This will cancel the booking and keep the current payment state unchanged.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    autofocus: true,
                    onChanged: (_) {
                      if (reasonError != null &&
                          reasonCtrl.text.trim().isNotEmpty) {
                        setDialogState(() => reasonError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Cancellation reason (required)',
                      errorText: reasonError,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accent,
                ),
                onPressed: () {
                  final trimmedReason = reasonCtrl.text.trim();
                  if (trimmedReason.isEmpty) {
                    setDialogState(
                      () => reasonError = 'Cancellation reason is required.',
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, trimmedReason);
                },
                child: const Text('Cancel Booking'),
              ),
            ],
          ),
        );
      },
    );
    reasonCtrl.dispose();

    if (reason == null) return;

    setState(() => _isMutating = true);
    try {
      await AdminRepository.cancelBooking(
        bookingId: widget.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully.')),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _claimIssue() async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await AdminRepository.claimBookingIssue(widget.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue claimed successfully.')),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _releaseIssue() async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await AdminRepository.releaseBookingIssue(widget.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue released successfully.')),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _assignRider() async {
    final currentRiderId =
        (_bookingData?['driverId'] ?? _bookingData?['riderId'])
            ?.toString()
            .trim();
    final actionLabel = currentRiderId != null && currentRiderId.isNotEmpty
        ? 'Reassign Rider'
        : 'Assign Rider';

    final selection = await showDialog<_RiderAssignmentDialogResult>(
      context: context,
      builder: (_) => _AssignRiderDialog(
        bookingId: widget.bookingId,
        bookingType: (_bookingData?['bookingType'] ?? 'now').toString(),
        actionLabel: actionLabel,
        initialRiderId: currentRiderId,
      ),
    );

    if (selection == null) return;

    setState(() => _isMutating = true);
    try {
      await AdminRepository.assignRiderToBooking(
        bookingId: widget.bookingId,
        riderId: selection.riderId,
        reason: selection.reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$actionLabel completed successfully.')),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AdminRepository.describeError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
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

  Future<void> _addAdditionalCharge() async {
    if (_isMutating) return;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var selectedType = AdminRepository.additionalChargeTypeLabels.keys.first;
    String? formError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Additional Charge'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Charge type',
                      ),
                      items: AdminRepository.additionalChargeTypeLabels.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₱ ',
                        errorText: formError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) {
                      setDialogState(
                        () => formError = 'Enter an amount greater than zero.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, {
                      'type': selectedType,
                      'amount': amount,
                      'notes': notesCtrl.text.trim(),
                    });
                  },
                  child: const Text('Add Charge'),
                ),
              ],
            );
          },
        );
      },
    );
    amountCtrl.dispose();
    notesCtrl.dispose();

    if (result == null) return;

    setState(() => _isMutating = true);
    try {
      await AdminRepository.addBookingAdditionalCharge(
        bookingId: widget.bookingId,
        type: result['type'] as String,
        amount: (result['amount'] as num).toDouble(),
        notes: result['notes'] as String?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Additional charge added.')),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AdminRepository.describeError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _removeAdditionalCharge(String chargeId) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await AdminRepository.removeBookingAdditionalCharge(
        bookingId: widget.bookingId,
        chargeId: chargeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Additional charge removed.')),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AdminRepository.describeError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  /// Opens the date/time pickers to set (or clear) the pickup call time.
  /// Demurrage rules (1/3/5/6): an early arrival counts from the call time,
  /// a late arrival from actual arrival, and loading that starts before the
  /// call time counts from the loading start.
  Future<void> _editCallTime() async {
    final currentCallTime = AdminRepository.parseTimestamp(
      _bookingData?['pickupCallTime'],
    );

    // When a call time already exists offer to change or clear it.
    if (currentCallTime != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final viewportWidth = MediaQuery.of(dialogContext).size.width;
          final dialogWidth = viewportWidth > 560 ? 420.0 : viewportWidth * 0.82;
          return AlertDialog(
            title: const Text('Call Time'),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current call time: '
                    '${DateFormat('EEE, MMM d, h:mm a').format(currentCallTime)}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Demurrage counts from the call time when the unit '
                    'arrives earlier, from the arrival when it is late, '
                    'and from the loading start when loading begins '
                    'before the call time.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'clear'),
                child: const Text('Clear'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accent,
                ),
                onPressed: () => Navigator.pop(dialogContext, 'change'),
                child: const Text('Change'),
              ),
            ],
          );
        },
      );
      if (!mounted || choice == null) return;

      if (choice == 'clear') {
        setState(() => _isMutating = true);
        try {
          await AdminRepository.setBookingCallTime(
            bookingId: widget.bookingId,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call time cleared.')),
          );
          await _loadBooking();
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AdminRepository.describeError(error)),
              backgroundColor: Colors.red,
            ),
          );
        } finally {
          if (mounted) {
            setState(() => _isMutating = false);
          }
        }
        return;
      }
    }

    final initialDate = currentCallTime ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 1),
      lastDate: DateTime(initialDate.year + 1),
      helpText: 'Pickup call time date',
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: 'Pickup call time',
    );
    if (!mounted || pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _isMutating = true);
    try {
      await AdminRepository.setBookingCallTime(
        bookingId: widget.bookingId,
        callTime: combined,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Call time set to ${DateFormat('MMM d, h:mm a').format(combined)}.',
          ),
        ),
      );
      await _loadBooking();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AdminRepository.describeError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bookingData == null && _loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadBooking, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_bookingData == null) {
      return const Center(child: Text('Booking not found.'));
    }

    final d = _bookingData!;
    final status = d['status'] ?? 'unknown';
    final issueStatus = (d['issueStatus'] ?? '').toString();
    final issueOwner = (d['issueOwner'] ?? '').toString();
    final canAssign = AdminRepository.canAssignBookingStatus(status);
    final hasAssignedRider = (d['driverId'] ?? d['riderId'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    final canCancel = AdminRepository.canCancelBookingStatus(status);
    final canManageIssue =
        issueStatus.isNotEmpty ||
        (d['cancellationReason'] ?? '').toString().isNotEmpty;
    final actionButtons = <Widget>[
      if (canAssign)
        OutlinedButton.icon(
          onPressed: _isMutating ? null : _assignRider,
          icon: Icon(
            hasAssignedRider
                ? Icons.swap_horiz_outlined
                : Icons.person_add_alt_1_outlined,
            size: 16,
          ),
          label: Text(hasAssignedRider ? 'Reassign Rider' : 'Assign Rider'),
        ),
      OutlinedButton.icon(
        onPressed: _isMutating ? null : _addNote,
        icon: const Icon(Icons.note_add_outlined, size: 16),
        label: const Text('Add Note'),
      ),
      if (canManageIssue)
        OutlinedButton.icon(
          onPressed: _isMutating
              ? null
              : issueOwner.isNotEmpty
              ? _releaseIssue
              : _claimIssue,
          icon: Icon(
            issueOwner.isNotEmpty
                ? Icons.assignment_return_outlined
                : Icons.assignment_ind_outlined,
            size: 16,
          ),
          label: Text(issueOwner.isNotEmpty ? 'Release Issue' : 'Claim Issue'),
        ),
      if (canCancel)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accent),
          onPressed: _isMutating ? null : _cancelBooking,
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('Cancel Booking'),
        ),
    ];

    final deliveryPhotosMap = _asMap(_bookingData?['deliveryPhotosMap']);
    final deliveryPhotosList =
        (_bookingData?['deliveryPhotos'] as List?) ?? [];
    final customerReportUrls = <String>[];
    final rawCustomerPhotos = _bookingData?['customerDeliveryPhotos'];
    if (rawCustomerPhotos is List) {
      for (final item in rawCustomerPhotos) {
        if (item is Map) {
          final url = (item['url'] ?? '').toString().trim();
          if (url.startsWith('http')) {
            customerReportUrls.add(url);
          }
        }
      }
    }

    // Debug logging for photo diagnostics
    debugPrint('[BookingDetail] deliveryPhotosMap keys: ${deliveryPhotosMap.keys.toList()}');
    debugPrint('[BookingDetail] deliveryPhotosMap isEmpty: ${deliveryPhotosMap.isEmpty}');
    debugPrint('[BookingDetail] deliveryPhotosList length: ${deliveryPhotosList.length}');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactActions = constraints.maxWidth < 900;
        final stackDetailCards = constraints.maxWidth < 1120;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compactActions) ...[
                TextButton.icon(
                  onPressed: () => context.go('/bookings'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Bookings'),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/bookings'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Bookings'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: actionButtons,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (stackDetailCards) ...[
                _BookingInfoCard(d: d, bookingId: widget.bookingId),
                const SizedBox(height: 16),
                _StatusTimelineCard(d: d),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _BookingInfoCard(
                        d: d,
                        bookingId: widget.bookingId,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: _StatusTimelineCard(d: d)),
                  ],
                ),
              const SizedBox(height: 16),
              if (stackDetailCards) ...[
                _PaymentCard(d: d),
                const SizedBox(height: 16),
                _DemurrageCard(d: d, onEditCallTime: _editCallTime),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PaymentCard(d: d)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DemurrageCard(d: d, onEditCallTime: _editCallTime),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              _AdditionalChargesCard(
                data: d,
                canEdit: AdminRepository.canCancelBookingStatus(d['status']),
                onAdd: _addAdditionalCharge,
                onRemove: _removeAdditionalCharge,
              ),
              const SizedBox(height: 16),
              _SupportNotesCard(bookingId: widget.bookingId, d: d),
              const SizedBox(height: 16),
              if (deliveryPhotosMap.isNotEmpty)
                _CategorizedDeliveryPhotosCard(
                  photosMap: deliveryPhotosMap,
                )
              else if ((d['deliveryPhotos'] as List?)?.isNotEmpty == true)
                _FlatDeliveryPhotosCard(
                  urls: (d['deliveryPhotos'] as List)
                      .whereType<String>()
                      .where((url) => url.startsWith('http'))
                      .toList(),
                ),
              if (customerReportUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FlatDeliveryPhotosCard(
                  title: 'Customer Delivery Report Photos',
                  urls: customerReportUrls,
                ),
              ],
            ],
          ),
        );
      },
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
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SectionHeader(title: 'Booking Details'),
                StatusBadge(d['status'] ?? 'unknown'),
              ],
            ),
            const SizedBox(height: 16),
            if ((d['tripNumber'] ?? '').toString().isNotEmpty)
              _buildRow('Trip Ticket', d['tripNumber'].toString()),
            _buildRow('ID', bookingId),
            if (created != null)
              _buildRow(
                'Created',
                DateFormat('MMM d, yyyy – h:mm a').format(created),
              ),
            _buildRow('Customer', d['customerName'] ?? d['userName'] ?? '—'),
            _buildRow(
              'Customer Phone',
              d['customerPhone'] ?? d['userPhone'] ?? '—',
            ),
            _buildRow('Rider', d['riderName'] ?? '—'),
            if ((d['partnerName'] ?? '').toString().trim().isNotEmpty)
              _buildRow('Partner', d['partnerName'].toString()),
            if (((d['partnerReportEmails'] as List?) ?? const []).isNotEmpty)
              _buildRow(
                'Partner Reports',
                ((d['partnerReportEmails'] as List)
                        .map((value) => value.toString())
                        .join(', ')),
              ),
            if (((d['partnerReportPhones'] as List?) ?? const []).isNotEmpty)
              _buildRow(
                'Partner Numbers',
                ((d['partnerReportPhones'] as List)
                        .map((value) => value.toString())
                        .join(', ')),
              ),
            _buildRow('Vehicle', d['vehicleType'] ?? d['truckType'] ?? '—'),
            const Divider(color: AdminTheme.divider),
            _buildRow('Pickup', d['pickupAddress'] ?? '—'),
            _buildRow('Dropoff', d['dropoffAddress'] ?? '—'),
            _buildRow('Receiver', d['receiverName'] ?? '—'),
            _buildRow('Receiver Phone', d['receiverPhone'] ?? '—'),
            _buildRow('Distance', '${d['distance'] ?? '—'} km'),
            _buildRow('Payment Method', d['paymentMethod'] ?? '—'),
            if ((d['notes'] ?? '').toString().isNotEmpty)
              _buildRow('Delivery Notes', d['notes'].toString()),
            if ((d['cancellationReason'] ?? '').toString().isNotEmpty) ...[
              const Divider(color: AdminTheme.divider),
              _buildRow('Cancellation Reason', d['cancellationReason'] ?? '—'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) => Padding(
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
    // Not a booking status — marks when the pickup documents (Service
    // Invoice / POD) were received, which also ends the loading demurrage.
    ('pickup_docs_received', 'Documents Received (Pickup)', ''),
    ('in_transit', 'In Transit', 'inTransitAt'),
    ('arrived_at_dropoff', 'Arrived at Dropoff', 'arrivedAtDropoffAt'),
    ('unloading', 'Unloading Started', 'unloadingStartedAt'),
    ('unloading_complete', 'Unloading Complete', 'unloadingCompletedAt'),
    // Not a booking status — marks the receiving milestone when the
    // receiver's documents were received/signed (before completion).
    ('docs_received', 'Documents Received / Signed', ''),
    ('completed', 'Completed', 'completedAt'),
  ];

  /// The demurrage fields (`loadingStartedAt` / `unloadingStartedAt`) record
  /// the ARRIVAL click, which can be hours before work physically starts.
  /// The stage photos carry the real start times, so prefer those for the
  /// Loading/Unloading "Started" rows and fall back to the arrival stamps.
  static DateTime? _stagePhotoTime(
    Map<String, dynamic> d,
    List<String> keys,
  ) {
    final photos = _asMap(d['deliveryPhotosMap']);
    for (final key in keys) {
      final value = photos[key];
      if (value is Map) {
        final ts = AdminRepository.parseTimestamp(
          value['uploadedAt'] ?? value['timestamp'],
        );
        if (ts != null) return ts;
      }
    }
    return null;
  }

  /// Earliest uploadedAt among prefixed stage photos (e.g. `service_invoice_1`,
  /// `service_invoice_2`) — the rider queues invoices under numbered keys.
  static DateTime? _earliestStagePhotoTime(
    Map<String, dynamic> d,
    String prefix,
  ) {
    final photos = _asMap(d['deliveryPhotosMap']);
    DateTime? earliest;
    for (final entry in photos.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final value = entry.value;
      if (value is Map) {
        final ts = AdminRepository.parseTimestamp(
          value['uploadedAt'] ?? value['timestamp'],
        );
        if (ts != null && (earliest == null || ts.isBefore(earliest))) {
          earliest = ts;
        }
      }
    }
    return earliest;
  }

  static DateTime? _resolveTimelineTimestamp(
    Map<String, dynamic> d,
    String statusKey,
    String tsField,
  ) {
    switch (statusKey) {
      case 'arrived_at_pickup':
        return AdminRepository.parseTimestamp(d['arrivedAtPickupAt']) ??
            AdminRepository.parseTimestamp(d['loadingStartedAt']);
      case 'loading':
        return _stagePhotoTime(d, [
              'start_loading',
              'start_loading_photo',
            ]) ??
            AdminRepository.parseTimestamp(d['loadingStartedAt']);
      case 'pickup_docs_received':
        // The Service Invoice (POD) marks the pickup documents as received —
        // the same instant that ends the loading demurrage count.
        return AdminRepository.parseTimestamp(d['loadingDocsReceivedAt']) ??
            _stagePhotoTime(d, ['service_invoice', 'invoice']) ??
            _earliestStagePhotoTime(d, 'service_invoice_');
      case 'arrived_at_dropoff':
        return AdminRepository.parseTimestamp(d['arrivedAtDropoffAt']) ??
            AdminRepository.parseTimestamp(d['unloadingStartedAt']);
      case 'unloading':
        return _stagePhotoTime(d, [
              'start_unloading',
              'start_unloading_photo',
            ]) ??
            AdminRepository.parseTimestamp(d['unloadingStartedAt']);
      case 'docs_received':
        // Prefer the signature-capture timestamp (PHT ISO string written by
        // the rider app the moment the receiver signed), then the signature
        // photo upload time, then completion as a legacy fallback.
        final signedAt = AdminRepository.parseTimestamp(
          _asMap(d['deliveryPhotosMap'])['receiver_signature_timestamp'],
        );
        if (signedAt != null) return signedAt;
        return _stagePhotoTime(d, ['receiver_signature', 'signature']) ??
            AdminRepository.parseTimestamp(d['completedAt']);
    }
    return AdminRepository.parseTimestamp(d[tsField]);
  }

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
              final ts = _resolveTimelineTimestamp(d, statusKey, tsField);
              // "Documents Received" rows are milestones rather than booking
              // statuses: they light up as soon as a docs timestamp exists
              // (or once the flow has moved past their anchor step). The
              // pickup milestone anchors at In Transit, the dropoff one at
              // Completed.
              final isMilestoneStep = statusKey == 'docs_received' ||
                  statusKey == 'pickup_docs_received';
              final milestoneRank = statusKey == 'docs_received'
                  ? statusOrder.indexOf('completed')
                  : statusOrder.indexOf('in_transit');
              final stepIdx = isMilestoneStep
                  ? milestoneRank
                  : statusOrder.indexOf(statusKey);
              final isDone = isMilestoneStep
                  ? ts != null || (stepIdx >= 0 && stepIdx <= currentIdx)
                  : stepIdx >= 0 && stepIdx <= currentIdx;
              final isCurrent = !isMilestoneStep && statusKey == currentStatus;

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

class _AdditionalChargesCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _AdditionalChargesCard({
    required this.data,
    required this.canEdit,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final charges = (data['additionalCharges'] as List?)
            ?.whereType<Map>()
            .map((item) => MapEntry(
                  item['id']?.toString() ?? '',
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ))
            .toList() ??
        const <MapEntry<String, Map<String, dynamic>>>[];
    final total = (data['additionalChargesTotal'] ?? 0) as num;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader(title: 'Additional Charges')),
                if (canEdit)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Charge'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (charges.isEmpty)
              Text(
                'No additional charges recorded.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
              )
            else
              ...charges.map((entry) {
                final charge = entry.value;
                final label =
                    (charge['label'] ?? charge['type'] ?? 'Charge').toString();
                final notes = (charge['notes'] ?? '').toString().trim();
                final amount = (charge['amount'] ?? 0) as num;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: AdminTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (notes.isNotEmpty)
                              Text(
                                notes,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '₱ ${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          onPressed: () => onRemove(entry.key),
                          tooltip: 'Remove charge',
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AdminTheme.statusCancelled,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            const Divider(height: 20),
            Row(
              children: [
                Text(
                  'Total Additional Charges',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '₱ ${total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.primary,
                  ),
                ),
              ],
            ),
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
    final gross = (d['grossAmount'] ?? d['finalFare'] ?? 0) as num;
    final additionalCharges = (d['additionalChargesTotal'] ?? 0) as num;
    final tip = (d['tipAmount'] ?? 0) as num;
    final partnerNet = (d['partnerNetAmount'] ?? 0) as num;
    final adminFee = (d['adminFeeAmount'] ?? 0) as num;
    final vat = (d['vatAmount'] ?? 0) as num;
    final adminNet = (d['adminNetAmount'] ?? 0) as num;
    final refunded = (d['refundedAmount'] ?? 0) as num;
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
            _buildFinancialRow(
              'Estimated Fare',
              '₱ ${estimated.toStringAsFixed(2)}',
            ),
            _buildFinancialRow('Gross Amount', '₱ ${gross.toStringAsFixed(2)}'),
            _buildFinancialRow(
              'Final Fare',
              '₱ ${final_.toStringAsFixed(2)}',
              bold: true,
            ),
            _buildFinancialRow(
              'Additional Charges',
              '₱ ${additionalCharges.toStringAsFixed(2)}',
            ),
            _buildFinancialRow('Tip', '₱ ${tip.toStringAsFixed(2)}'),
            _buildFinancialRow(
              'Partner Net (80%)',
              '₱ ${partnerNet.toStringAsFixed(2)}',
            ),
            _buildFinancialRow(
              'Admin Fee (20%)',
              '₱ ${adminFee.toStringAsFixed(2)}',
            ),
            _buildFinancialRow(
              'VAT (inside 20%)',
              '₱ ${vat.toStringAsFixed(2)}',
            ),
            _buildFinancialRow(
              'Admin Net After VAT',
              '₱ ${adminNet.toStringAsFixed(2)}',
            ),
            if (refunded > 0)
              _buildFinancialRow(
                'Refunded Amount',
                '₱ ${refunded.toStringAsFixed(2)}',
              ),
            _buildFinancialRow('Payment Method', d['paymentMethod'] ?? '—'),
            _buildFinancialRow('Payment Status', payStatus),
            if (reconciliationStatus.toString().isNotEmpty)
              _buildFinancialRow(
                'Reconciliation',
                reconciliationStatus.toString(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                softWrap: true,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold ? AdminTheme.primary : AdminTheme.textPrimary,
                ),
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
    final issueOwner = (d['issueOwner'] ?? '').toString();
    final issueNotesCount = (d['issueNotesCount'] ?? 0) as int;
    final reconciliationStatus = (d['reconciliationStatus'] ?? '').toString();
    final cancellationReason = (d['cancellationReason'] ?? '').toString();
    final cancelledAt = AdminRepository.parseTimestamp(d['cancelledAt']);
    final issueAssignedAt = AdminRepository.parseTimestamp(
      d['issueAssignedAt'],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final chips = <Widget>[
                  if (issueStatus.isNotEmpty) StatusBadge(issueStatus),
                  if (reconciliationStatus.isNotEmpty)
                    StatusBadge(reconciliationStatus),
                ];
                final notesText = Text(
                  '$issueNotesCount note${issueNotesCount == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminTheme.textSecondary,
                  ),
                );

                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const SectionHeader(title: 'Issue History'),
                          ...chips,
                        ],
                      ),
                      const SizedBox(height: 8),
                      notesText,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const SectionHeader(title: 'Issue History'),
                          ...chips,
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    notesText,
                  ],
                );
              },
            ),
            if (issueOwner.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                issueAssignedAt != null
                    ? 'Claimed by $issueOwner on ${DateFormat('MMM d, yyyy – h:mm a').format(issueAssignedAt)}'
                    : 'Claimed by $issueOwner',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AdminTheme.textSecondary,
                ),
              ),
            ],
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
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final createdBy =
                                          (entry['createdBy'] ??
                                                  AdminConstants.adminUsername)
                                              .toString();
                                      final dateWidget = createdAt != null
                                          ? Text(
                                              DateFormat(
                                                'MMM d, yyyy – h:mm a',
                                              ).format(createdAt),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: AdminTheme.textSecondary,
                                              ),
                                            )
                                          : null;

                                      if (constraints.maxWidth < 460) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  createdBy,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                StatusBadge(
                                                  (entry['type'] ?? 'support')
                                                      .toString(),
                                                ),
                                              ],
                                            ),
                                            if (dateWidget != null) ...[
                                              const SizedBox(height: 6),
                                              dateWidget,
                                            ],
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  createdBy,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                StatusBadge(
                                                  (entry['type'] ?? 'support')
                                                      .toString(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (dateWidget != null) ...[
                                            const SizedBox(width: 12),
                                            dateWidget,
                                          ],
                                        ],
                                      );
                                    },
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
  final VoidCallback onEditCallTime;

  const _DemurrageCard({required this.d, required this.onEditCallTime});

  String _sourceLabel(String source) {
    switch (source) {
      case 'call_time':
        return 'from call time';
      case 'loading_start':
        return 'from start loading';
      case 'arrival':
        return 'from arrival';
      default:
        // Legacy bookings started counting at the arrival click.
        return 'from arrival';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadingFee = (d['loadingDemurrageFee'] ?? 0) as num;
    final unloadingFee = (d['unloadingDemurrageFee'] ?? 0) as num;
    final callTime = AdminRepository.parseTimestamp(d['pickupCallTime']);
    final demurrageStarted =
        AdminRepository.parseTimestamp(d['loadingStartedAt']) != null;
    final loadingSource =
        (d['loadingDemurrageStartSource'] ?? '').toString().trim();
    final loadingDocsEnd = AdminRepository.parseTimestamp(
          d['loadingDocsReceivedAt'],
        ) ??
        AdminRepository.parseTimestamp(d['loadingCompletedAt']);
    final signatureTs = AdminRepository.parseTimestamp(
      _asMap(d['deliveryPhotosMap'])['receiver_signature_timestamp'],
    );
    final unloadingDocsEnd = signatureTs ??
        AdminRepository.parseTimestamp(d['completedAt']) ??
        AdminRepository.parseTimestamp(d['unloadingCompletedAt']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Demurrage'),
            const SizedBox(height: 12),
            _buildCallTimeRow(context, callTime, demurrageStarted),
            const Divider(color: AdminTheme.divider),
            _buildDemurrageRow(
              'Demurrage Start (Pickup)',
              demurrageStarted
                  ? '${_fmt(d['loadingStartedAt'])} · ${_sourceLabel(loadingSource)}'
                  : _fmt(d['loadingStartedAt']),
            ),
            _buildDemurrageRow(
              'Demurrage End (Docs Received)',
              _fmt(loadingDocsEnd),
            ),
            _buildDemurrageRow(
              'Loading Fee',
              '₱ ${loadingFee.toStringAsFixed(2)}',
            ),
            const Divider(color: AdminTheme.divider),
            _buildDemurrageRow(
              'Demurrage Start (Arrival)',
              _fmt(d['unloadingStartedAt']),
            ),
            _buildDemurrageRow(
              'Demurrage End (Docs Received)',
              _fmt(unloadingDocsEnd),
            ),
            _buildDemurrageRow(
              'Unloading Fee',
              '₱ ${unloadingFee.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTimeRow(
    BuildContext context,
    DateTime? callTime,
    bool demurrageStarted,
  ) {
    final value = callTime != null
        ? DateFormat('EEE, MMM d, h:mm a').format(callTime)
        : 'Not set';
    final canEdit = !demurrageStarted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              'Call Time (Pickup)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    callTime != null ? FontWeight.w600 : FontWeight.w400,
                color: callTime != null
                    ? AdminTheme.textPrimary
                    : AdminTheme.textSecondary,
              ),
            ),
          ),
          Tooltip(
            message: canEdit
                ? 'Set or clear the pickup call time'
                : 'Demurrage already started — the call time is locked',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: canEdit ? onEditCallTime : null,
              icon: const Icon(Icons.edit_outlined, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic ts) {
    final dt = AdminRepository.parseTimestamp(ts);
    return dt != null ? DateFormat('MMM d, h:mm a').format(dt) : '—';
  }

  Widget _buildDemurrageRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            softWrap: true,
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

class _PhotoCategory {
  final String title;
  final List<String> keys;
  final List<String> keyPrefixes;

  const _PhotoCategory({
    required this.title,
    required this.keys,
    this.keyPrefixes = const [],
  });
}

class _CategorizedDeliveryPhotosCard extends StatelessWidget {
  final Map<String, dynamic> photosMap;

  const _CategorizedDeliveryPhotosCard({required this.photosMap});

  static const _categories = <_PhotoCategory>[
    _PhotoCategory(
      title: 'Arrived at Warehouse',
      keys: [
        'warehouse_arrival',
        'pickup_arrival',
        'warehouse_arrival_photo_url',
        'pickup_arrival_photo_url',
      ],
    ),
    _PhotoCategory(
      title: 'Start Loading',
      keys: [
        'start_loading',
        'start_loading_photo',
        'start_loading_photo_url',
        'loading_photo_url',
      ],
    ),
    _PhotoCategory(
      title: 'Finish Loading',
      keys: [
        'finish_loading',
        'finished_loading',
        'finish_loading_photo',
        'finished_loading_photo',
        'finish_loading_photo_url',
      ],
    ),
    _PhotoCategory(
      title: 'Service Invoice (POD)',
      keys: ['service_invoice', 'pod', 'invoice'],
      keyPrefixes: ['service_invoice_'],
    ),
    _PhotoCategory(
      title: 'Arrived at Destination',
      keys: [
        'destination_arrival',
        'dropoff_arrival',
        'destination_arrival_photo_url',
        'dropoff_arrival_photo_url',
      ],
    ),
    _PhotoCategory(
      title: 'Start Unloading',
      keys: [
        'start_unloading',
        'start_unloading_photo',
        'start_unloading_photo_url',
      ],
    ),
    _PhotoCategory(
      title: 'Finish Unloading',
      keys: [
        'finish_unloading',
        'finished_unloading',
        'finish_unloading_photo',
        'finished_unloading_photo',
        'finish_unloading_photo_url',
        'unloading_photo_url',
      ],
    ),
    _PhotoCategory(
      title: 'Damages',
      keys: [
        'damage_photo',
        'damaged_boxes',
        'empty_truck',
        'damage_photos',
        'damaged_items',
      ],
    ),
    _PhotoCategory(
      title: 'Signed Documents',
      keys: [
        'receiver_signature',
        'signature',
        'receiver_signature_url',
        'signed_documents',
      ],
      keyPrefixes: ['signed_documents_'],
    ),
    _PhotoCategory(
      title: "Picture of ID's",
      keys: ['receiver_id', 'receiver_id_photo', 'receiver_id_photo_url'],
    ),
  ];

  List<String> _extractUrls(dynamic value) {
    final urls = <String>[];
    if (value == null) return urls;

    if (value is List) {
      for (final item in value) {
        urls.addAll(_extractUrls(item));
      }
      return urls;
    }

    if (value is Map) {
      for (final field in ['url', 'imageUrl', 'downloadUrl']) {
        final url = value[field]?.toString().trim();
        if (url != null &&
            url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'))) {
          urls.add(url);
          return urls;
        }
      }
      // Some maps hold nested photo lists (e.g. damage_photos).
      for (final entry in value.values) {
        urls.addAll(_extractUrls(entry));
      }
      return urls;
    }

    final text = value.toString().trim();
    if (text.isNotEmpty &&
        (text.startsWith('http://') || text.startsWith('https://'))) {
      urls.add(text);
    }
    return urls;
  }

  List<String> _categoryUrls(_PhotoCategory category) {
    final urls = <String>[];
    for (final key in category.keys) {
      urls.addAll(_extractUrls(photosMap[key]));
    }
    for (final prefix in category.keyPrefixes) {
      for (final entry in photosMap.entries) {
        if (entry.key.startsWith(prefix)) {
          urls.addAll(_extractUrls(entry.value));
        }
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = _categories
        .where((category) => _categoryUrls(category).isNotEmpty)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Delivery Photos'),
            const SizedBox(height: 12),
            if (visibleCategories.isEmpty)
              const EmptyState(
                message: 'No delivery photos uploaded yet',
                icon: Icons.photo_library_outlined,
              )
            else
              ...visibleCategories.map((category) {
                final urls = _categoryUrls(category);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                          children: urls
                            .map(
                              (url) => GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                      child: CachedNetworkImage(
                                        imageUrl: url,
                                        errorWidget:
                                            (context, url, error) => Container(
                                              width: 300,
                                              height: 200,
                                              color: Colors.grey[200],
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Failed to load image',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    url.length > 60
                                                        ? '${url.substring(0, 60)}...'
                                                        : url,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      color: Colors.grey[400],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                      ),
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
                                    errorWidget:
                                        (context, url, error) => Container(
                                          width: 140,
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FlatDeliveryPhotosCard extends StatelessWidget {
  final List<String> urls;
  final String title;
  const _FlatDeliveryPhotosCard({
    required this.urls,
    this.title = 'Delivery Photos',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: urls
                  .map(
                    (url) => GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: CachedNetworkImage(
                              imageUrl: url,
                              errorWidget: (context, url, error) => Container(
                                width: 140,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey),
                              ),
                            ),
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
                          errorWidget: (context, url, error) => Container(
                            width: 140,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
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

class _AssignRiderDialog extends StatefulWidget {
  final String bookingId;
  final String bookingType;
  final String actionLabel;
  final String? initialRiderId;

  const _AssignRiderDialog({
    required this.bookingId,
    required this.bookingType,
    required this.actionLabel,
    this.initialRiderId,
  });

  @override
  State<_AssignRiderDialog> createState() => _AssignRiderDialogState();
}

class _AssignRiderDialogState extends State<_AssignRiderDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final Set<String> _availableRiderIds = <String>{};

  String? _selectedRiderId;
  String? _formError;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allRiders = const <Map<String, dynamic>>[];
  Map<String, List<Map<String, dynamic>>> _activeBookingsByRider =
      const <String, List<Map<String, dynamic>>>{};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRiderId?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedRiderId = initial;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Map<String, List<Map<String, dynamic>>> _groupRiders(
    List<Map<String, dynamic>> riders,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final rider in riders) {
      final unitName =
          (rider['unitName'] ?? 'Independent Units').toString().trim();
      grouped
          .putIfAbsent(
            unitName.isEmpty ? 'Independent Units' : unitName,
            () => <Map<String, dynamic>>[],
          )
          .add(rider);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return {
      for (final entry in entries)
        entry.key: entry.value
          ..sort((a, b) {
            final onlineCompare =
                ((b['isOnline'] == true) ? 1 : 0) -
                ((a['isOnline'] == true) ? 1 : 0);
            if (onlineCompare != 0) return onlineCompare;
            return (a['name'] ?? '')
                .toString()
                .toLowerCase()
                .compareTo((b['name'] ?? '').toString().toLowerCase());
          }),
    };
  }

  List<Map<String, dynamic>> _filterRiders(List<Map<String, dynamic>> riders) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return riders;

    return riders.where((rider) {
      final haystack = [
        rider['name'],
        rider['plateNumber'],
        rider['vehicleType'],
        rider['unitName'],
        rider['phoneNumber'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();
  }

  String _bookingReference(Map<String, dynamic> booking) {
    final tripNumber = (booking['tripNumber'] ?? '').toString().trim();
    if (tripNumber.isNotEmpty) return tripNumber;
    final id = (booking['id'] ?? '').toString();
    if (id.length <= 8) return id;
    return id.substring(0, 8).toUpperCase();
  }

  String _riderSubtitle(Map<String, dynamic> rider) {
    final parts = [
      (rider['vehicleType'] ?? 'Vehicle').toString().trim(),
      if ((rider['phoneNumber'] ?? '').toString().trim().isNotEmpty)
        rider['phoneNumber'].toString().trim(),
    ];
    return parts.join(' • ');
  }

  String _gpsStatus(Map<String, dynamic> rider) {
    final gpsUpdatedAt = AdminRepository.parseTimestamp(
      rider['locationUpdatedAt'],
    );
    if (gpsUpdatedAt == null) return 'No GPS ping';
    return 'GPS ${DateFormat('MMM d, h:mm a').format(gpsUpdatedAt)}';
  }

  List<Map<String, dynamic>> _activeBookingsForRider(
    Map<String, dynamic> rider,
    Map<String, List<Map<String, dynamic>>> activeByRider,
  ) {
    final riderId = (rider['id'] ?? '').toString().trim();
    if (riderId.isEmpty) return const <Map<String, dynamic>>[];
    return activeByRider[riderId] ?? const <Map<String, dynamic>>[];
  }

  String? _capacityConflictForRider(
    Map<String, dynamic> rider,
    Map<String, List<Map<String, dynamic>>> activeByRider,
  ) {
    return RiderBookingCapacity.conflictMessage(
      candidateBookingType: widget.bookingType,
      liveBookings: _activeBookingsForRider(rider, activeByRider),
      excludingBookingId: widget.bookingId,
      referenceBuilder: (booking) {
        final reference =
            (booking['tripNumber'] ?? booking['id'] ?? '').toString();
        if (reference.length <= 8) return reference;
        return reference.substring(0, 8).toUpperCase();
      },
    );
  }

  Map<String, dynamic>? _busyBookingForRider(
    Map<String, dynamic> rider,
    Map<String, List<Map<String, dynamic>>> activeByRider,
  ) {
    for (final booking in _activeBookingsForRider(rider, activeByRider)) {
      if ((booking['id'] ?? '').toString() != widget.bookingId) {
        return booking;
      }
    }

    final pointerBookingId = (rider['activeBookingId'] ?? '').toString().trim();
    if (pointerBookingId.isNotEmpty &&
        pointerBookingId != widget.bookingId &&
        AdminRepository.isLiveAssignedBookingStatus(
          rider['activeBookingStatus'],
        )) {
      return {
        'id': pointerBookingId,
        'tripNumber': pointerBookingId,
      };
    }
    return null;
  }

  Future<void> _submit() async {
    final resolvedRiderId = _selectedRiderId?.trim() ?? '';
    final trimmedReason = _reasonCtrl.text.trim();
    final hasValidSelection =
        resolvedRiderId.isNotEmpty &&
        _availableRiderIds.contains(resolvedRiderId);

    if (!hasValidSelection) {
      setState(() => _formError = 'Please select a rider.');
      return;
    }
    if (trimmedReason.isEmpty) {
      setState(() => _formError = 'Assignment reason is required.');
      return;
    }

    final selectedRider = _allRiders.firstWhere(
      (rider) => (rider['id'] ?? '').toString() == resolvedRiderId,
      orElse: () => const <String, dynamic>{},
    );
    final capacityConflict = _capacityConflictForRider(
      selectedRider,
      _activeBookingsByRider,
    );
    if (capacityConflict != null) {
      setState(() => _formError = capacityConflict);
      return;
    }

    if (!mounted) return;

    Navigator.pop(
      context,
      _RiderAssignmentDialogResult(
        riderId: resolvedRiderId,
        reason: trimmedReason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.of(context).size.width;
    final dialogWidth = viewportWidth > 820 ? 640.0 : viewportWidth * 0.82;

    return AlertDialog(
      title: Text(widget.actionLabel),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose the registered unit that should handle this trip. Units can hold up to 2 active trips (1 scheduled + 1 realtime pickup); units already at that limit are locked.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                labelText: 'Search units',
                hintText: 'Name, plate, phone, vehicle, or unit',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear, size: 18),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminRepository.streamDispatchableRiders(),
                builder: (context, riderSnap) {
                  final allRiders =
                      riderSnap.data ?? const <Map<String, dynamic>>[];
                  _allRiders = allRiders;
                  _availableRiderIds
                    ..clear()
                    ..addAll(
                      allRiders
                          .map((rider) => (rider['id'] ?? '').toString())
                          .where((id) => id.isNotEmpty),
                    );

                  if (riderSnap.connectionState == ConnectionState.waiting &&
                      allRiders.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (riderSnap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Unable to load riders right now. ${AdminRepository.describeError(riderSnap.error!)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    );
                  }
                  if (allRiders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No active registered units are available.'),
                    );
                  }

                  final riders = _filterRiders(allRiders);
                  if (riders.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No units matched "$_searchQuery".',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                    );
                  }

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: AdminRepository.streamActiveAssignedBookings(),
                    builder: (context, activeSnap) {
                      if (activeSnap.connectionState ==
                              ConnectionState.waiting &&
                          !activeSnap.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (activeSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Unable to load rider availability right now. ${AdminRepository.describeError(activeSnap.error!)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }

                      final activeByRider =
                          <String, List<Map<String, dynamic>>>{};
                      for (final booking
                          in activeSnap.data ??
                              const <Map<String, dynamic>>[]) {
                        final riderId =
                            (booking['driverId'] ?? booking['riderId'] ?? '')
                                .toString()
                                .trim();
                        if (riderId.isNotEmpty) {
                          activeByRider
                              .putIfAbsent(riderId, () => [])
                              .add(booking);
                        }
                      }
                      _activeBookingsByRider = activeByRider;

                      final groupedRiders = _groupRiders(riders);
                      final visibleSelectedRiderId =
                          _availableRiderIds.contains(_selectedRiderId)
                          ? _selectedRiderId
                          : null;

                      return ListView.separated(
                        itemCount: groupedRiders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final entry = groupedRiders.entries.elementAt(index);
                          final unitRiders = entry.value;
                          final onlineCount = unitRiders
                              .where((rider) => rider['isOnline'] == true)
                              .length;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AdminTheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AdminTheme.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AdminTheme.statusActive
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$onlineCount/${unitRiders.length} online',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AdminTheme.statusActive,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...unitRiders.map((rider) {
                                  final riderId =
                                      (rider['id'] ?? '').toString();
                                  final busyBooking = _busyBookingForRider(
                                    rider,
                                    activeByRider,
                                  );
                                  final capacityConflict =
                                      _capacityConflictForRider(
                                        rider,
                                        activeByRider,
                                      );
                                  final isAtCapacity = capacityConflict != null;
                                  final isBusy = busyBooking != null;
                                  final isSelected =
                                      riderId == visibleSelectedRiderId;

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: isAtCapacity
                                        ? null
                                        : () => setState(() {
                                              _selectedRiderId = riderId;
                                              _formError = null;
                                            }),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      margin: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AdminTheme.primary
                                                .withValues(alpha: 0.06)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? AdminTheme.primary
                                              : AdminTheme.divider,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: riderId,
                                            groupValue: visibleSelectedRiderId,
                                            onChanged: isAtCapacity
                                                ? null
                                                : (value) {
                                                    setState(() {
                                                      _selectedRiderId = value;
                                                      _formError = null;
                                                    });
                                                  },
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        (rider['name'] ??
                                                                'Unnamed Rider')
                                                            .toString(),
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AdminTheme
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    if ((rider['plateNumber'] ??
                                                            '')
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AdminTheme
                                                              .primary
                                                              .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Text(
                                                          rider['plateNumber']
                                                              .toString()
                                                              .trim()
                                                              .toUpperCase(),
                                                          style: GoogleFonts
                                                              .inter(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800,
                                                            color: AdminTheme
                                                                .primary,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _riderSubtitle(rider),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: AdminTheme
                                                        .textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isAtCapacity
                                                        ? AdminTheme
                                                              .statusCancelled
                                                              .withValues(
                                                            alpha: 0.1,
                                                          )
                                                        : (isBusy
                                                              ? AdminTheme
                                                                    .statusPending
                                                                    .withValues(
                                                                    alpha: 0.1,
                                                                  )
                                                              : (rider['isOnline'] ==
                                                                        true
                                                                    ? AdminTheme
                                                                          .statusActive
                                                                          .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                    : AdminTheme
                                                                          .surface)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      999,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isAtCapacity
                                                        ? 'At capacity'
                                                        : (isBusy
                                                              ? 'Busy on ${_bookingReference(busyBooking)}'
                                                              : (rider['isOnline'] ==
                                                                        true
                                                                    ? 'Ready'
                                                                    : 'Offline')),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isAtCapacity
                                                          ? AdminTheme
                                                              .statusCancelled
                                                          : (isBusy
                                                                ? AdminTheme
                                                                      .statusPending
                                                                : (rider['isOnline'] ==
                                                                          true
                                                                      ? AdminTheme
                                                                          .statusActive
                                                                      : AdminTheme
                                                                          .textSecondary)),
                                                    ),
                                                  ),
                                                ),
                                                if (isAtCapacity) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    capacityConflict,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: AdminTheme
                                                          .statusCancelled,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ] else if (isBusy) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Unit has one active trip. This booking can be added as its second trip (1 scheduled + 1 realtime pickup).',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: AdminTheme
                                                          .statusPending,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 6),
                                                Text(
                                                  _gpsStatus(rider),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: AdminTheme
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              onChanged: (_) {
                if (_formError != null &&
                    _reasonCtrl.text.trim().isNotEmpty) {
                  setState(() => _formError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Assignment reason (required)',
                errorText: _formError,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _submit(),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
