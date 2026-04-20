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

  @override
  void initState() {
    super.initState();
    _loadBooking();
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
    String? selectedRiderId =
        (_bookingData?['driverId'] ?? _bookingData?['riderId'])
            ?.toString()
            .trim();
    final reasonCtrl = TextEditingController();
    final actionLabel = selectedRiderId != null && selectedRiderId.isNotEmpty
        ? 'Reassign Rider'
        : 'Assign Rider';

    final selection = await showDialog<_RiderAssignmentDialogResult>(
      context: context,
      builder: (dialogContext) {
        String? formError;
        final availableRiderIds = <String>{};

        Map<String, List<Map<String, dynamic>>> groupRiders(
          List<Map<String, dynamic>> riders,
        ) {
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final rider in riders) {
            final unitName = (rider['unitName'] ?? 'Independent Units')
                .toString()
                .trim();
            grouped
                .putIfAbsent(
                  unitName.isEmpty ? 'Independent Units' : unitName,
                  () => <Map<String, dynamic>>[],
                )
                .add(rider);
          }

          final entries = grouped.entries.toList()
            ..sort(
              (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
            );
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

        String bookingReference(Map<String, dynamic> booking) {
          final tripNumber = (booking['tripNumber'] ?? '').toString().trim();
          if (tripNumber.isNotEmpty) return tripNumber;
          final id = (booking['id'] ?? '').toString();
          if (id.length <= 8) return id;
          return id.substring(0, 8).toUpperCase();
        }

        String riderSubtitle(Map<String, dynamic> rider) {
          final parts = [
            (rider['vehicleType'] ?? 'Vehicle').toString().trim(),
            if ((rider['plateNumber'] ?? '').toString().trim().isNotEmpty)
              rider['plateNumber'].toString().trim(),
            if ((rider['phoneNumber'] ?? '').toString().trim().isNotEmpty)
              rider['phoneNumber'].toString().trim(),
          ];
          return parts.join(' • ');
        }

        String gpsStatus(Map<String, dynamic> rider) {
          final gpsUpdatedAt = AdminRepository.parseTimestamp(
            rider['locationUpdatedAt'],
          );
          if (gpsUpdatedAt == null) return 'No GPS ping';
          return 'GPS ${DateFormat('MMM d, h:mm a').format(gpsUpdatedAt)}';
        }

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final viewportWidth = MediaQuery.of(dialogContext).size.width;
            final dialogWidth = viewportWidth > 820
                ? 640.0
                : viewportWidth * 0.82;

            return AlertDialog(
              title: Text(actionLabel),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose the registered unit that should handle this trip. Units already carrying another active trip are locked.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: AdminRepository.streamDispatchableRiders(),
                        builder: (context, riderSnap) {
                          final riders =
                              riderSnap.data ?? const <Map<String, dynamic>>[];
                          availableRiderIds
                            ..clear()
                            ..addAll(
                              riders
                                  .map((rider) => (rider['id'] ?? '').toString())
                                  .where((id) => id.isNotEmpty),
                            );

                          if (riderSnap.connectionState ==
                                  ConnectionState.waiting &&
                              riders.isEmpty) {
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
                                'Unable to load riders right now. ${riderSnap.error}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }
                          if (riders.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No active registered units are available.',
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Unable to load rider availability right now. ${activeSnap.error}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                );
                              }

                              final activeByRider =
                                  <String, Map<String, dynamic>>{};
                              for (final booking
                                  in activeSnap.data ??
                                      const <Map<String, dynamic>>[]) {
                                final riderId =
                                    (booking['driverId'] ??
                                            booking['riderId'] ??
                                            '')
                                        .toString()
                                        .trim();
                                if (riderId.isNotEmpty) {
                                  activeByRider[riderId] = booking;
                                }
                              }

                              final groupedRiders = groupRiders(riders);
                              final visibleSelectedRiderId =
                                  availableRiderIds.contains(selectedRiderId)
                                  ? selectedRiderId
                                  : null;

                              return ListView.separated(
                                itemCount: groupedRiders.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final entry = groupedRiders.entries.elementAt(
                                    index,
                                  );
                                  final unitRiders = entry.value;
                                  final onlineCount = unitRiders
                                      .where((rider) => rider['isOnline'] == true)
                                      .length;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AdminTheme.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AdminTheme.divider,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                  color:
                                                      AdminTheme.statusActive,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ...unitRiders.map((rider) {
                                          final riderId =
                                              (rider['id'] ?? '').toString();
                                          final activeBooking =
                                              activeByRider[riderId];
                                          final isBusyWithOtherBooking =
                                              activeBooking != null &&
                                              (activeBooking['id'] ?? '') !=
                                                  widget.bookingId;
                                          final isSelected =
                                              riderId == visibleSelectedRiderId;

                                          return InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: isBusyWithOtherBooking
                                                ? null
                                                : () => setDialogState(() {
                                                    selectedRiderId = riderId;
                                                    formError = null;
                                                  }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AdminTheme.primary
                                                          .withValues(
                                                            alpha: 0.06,
                                                          )
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
                                                    groupValue:
                                                        visibleSelectedRiderId,
                                                    onChanged:
                                                        isBusyWithOtherBooking
                                                        ? null
                                                        : (value) {
                                                            setDialogState(() {
                                                              selectedRiderId =
                                                                  value;
                                                              formError = null;
                                                            });
                                                          },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          (rider['name'] ??
                                                                  'Unnamed Rider')
                                                              .toString(),
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AdminTheme
                                                                .textPrimary,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          riderSubtitle(rider),
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11,
                                                            color: AdminTheme
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                isBusyWithOtherBooking
                                                                ? AdminTheme
                                                                      .statusPending
                                                                      .withValues(
                                                                        alpha: 0.1,
                                                                      )
                                                                : (rider['isOnline'] ==
                                                                          true
                                                                      ? AdminTheme.statusActive.withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                      : AdminTheme
                                                                            .surface),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            isBusyWithOtherBooking
                                                                ? 'Busy on ${bookingReference(activeBooking)}'
                                                                : (rider['isOnline'] ==
                                                                          true
                                                                      ? 'Ready'
                                                                      : 'Offline'),
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  isBusyWithOtherBooking
                                                                  ? AdminTheme
                                                                        .statusPending
                                                                  : (rider['isOnline'] ==
                                                                            true
                                                                        ? AdminTheme.statusActive
                                                                        : AdminTheme.textSecondary),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          gpsStatus(rider),
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
                      controller: reasonCtrl,
                      onChanged: (_) {
                        if (formError != null &&
                            reasonCtrl.text.trim().isNotEmpty) {
                          setDialogState(() => formError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Assignment reason (required)',
                        errorText: formError,
                      ),
                      maxLines: 2,
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
                    final resolvedRiderId = selectedRiderId?.trim() ?? '';
                    final trimmedReason = reasonCtrl.text.trim();
                    final hasValidSelection =
                        resolvedRiderId.isNotEmpty &&
                        availableRiderIds.contains(resolvedRiderId);

                    if (!hasValidSelection) {
                      setDialogState(
                        () => formError = 'Please select a rider.',
                      );
                      return;
                    }
                    if (trimmedReason.isEmpty) {
                      setDialogState(
                        () =>
                            formError = 'Assignment reason is required.',
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _RiderAssignmentDialogResult(
                        riderId: resolvedRiderId,
                        reason: trimmedReason,
                      ),
                    );
                  },
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );
    reasonCtrl.dispose();

    if (selection == null) return;

    final riderId = selection.riderId;
    final reason = selection.reason;

    setState(() => _isMutating = true);
    try {
      await AdminRepository.assignRiderToBooking(
        bookingId: widget.bookingId,
        riderId: riderId,
        reason: reason,
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
                _DemurrageCard(d: d),
              ] else
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
              if ((d['deliveryPhotos'] as List?)?.isNotEmpty == true)
                _DeliveryPhotosCard(
                  photos: List<String>.from(d['deliveryPhotos']),
                ),
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
            _buildRow('Vehicle', d['vehicleType'] ?? d['truckType'] ?? '—'),
            const Divider(color: AdminTheme.divider),
            _buildRow('Pickup', d['pickupAddress'] ?? '—'),
            _buildRow('Dropoff', d['dropoffAddress'] ?? '—'),
            _buildRow('Receiver', d['receiverName'] ?? '—'),
            _buildRow('Receiver Phone', d['receiverPhone'] ?? '—'),
            _buildRow('Distance', '${d['distance'] ?? '—'} km'),
            _buildRow('Payment Method', d['paymentMethod'] ?? '—'),
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
    final gross = (d['grossAmount'] ?? d['finalFare'] ?? 0) as num;
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
            _buildDemurrageRow('Loading Started', _fmt(d['loadingStartedAt'])),
            _buildDemurrageRow(
              'Loading Completed',
              _fmt(d['loadingCompletedAt']),
            ),
            _buildDemurrageRow(
              'Loading Fee',
              '₱ ${loadingFee.toStringAsFixed(2)}',
            ),
            const Divider(color: AdminTheme.divider),
            _buildDemurrageRow(
              'Unloading Started',
              _fmt(d['unloadingStartedAt']),
            ),
            _buildDemurrageRow(
              'Unloading Completed',
              _fmt(d['unloadingCompletedAt']),
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

  String _fmt(dynamic ts) {
    final dt = AdminRepository.parseTimestamp(ts);
    return dt != null ? DateFormat('h:mm a').format(dt) : '—';
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
