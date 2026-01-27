import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';

class RiderReportsScreen extends StatefulWidget {
  const RiderReportsScreen({super.key});

  @override
  State<RiderReportsScreen> createState() => _RiderReportsScreenState();
}

enum _ReportRange { today, week, month }

class _ReportBookingRow {
  final String bookingId;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double distanceKm;
  final Duration loadingDuration;
  final Duration unloadingDuration;

  _ReportBookingRow({
    required this.bookingId,
    required this.status,
    required this.createdAt,
    required this.completedAt,
    required this.distanceKm,
    required this.loadingDuration,
    required this.unloadingDuration,
  });
}

class _RiderReportsScreenState extends State<RiderReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RiderAuthService _authService = RiderAuthService();

  _ReportRange _range = _ReportRange.week;
  bool _isLoading = true;
  String? _error;

  List<_ReportBookingRow> _rows = [];

  DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTimeRange _currentRange() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    switch (_range) {
      case _ReportRange.today:
        return DateTimeRange(
          start: startOfToday,
          end: startOfToday.add(const Duration(days: 1)),
        );
      case _ReportRange.week:
        final start = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case _ReportRange.month:
        final start = DateTime(now.year, now.month, 1);
        final end = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return DateTimeRange(start: start, end: end);
    }
  }

  Duration _safeDuration(DateTime? start, DateTime? end, DateTime fallbackEnd) {
    if (start == null) return Duration.zero;
    final effectiveEnd = end ?? fallbackEnd;
    final d = effectiveEnd.difference(start);
    if (d.isNegative) return Duration.zero;
    return d;
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rider = await _authService.getCurrentRider();
      if (!mounted) return;
      if (rider == null) {
        setState(() {
          _rows = [];
          _isLoading = false;
          _error = 'No rider session found.';
        });
        return;
      }

      final range = _currentRange();

      final snap = await _firestore
          .collection('bookings')
          .where('driverId', isEqualTo: rider.riderId)
          .get();

      final now = DateTime.now();

      final rows = <_ReportBookingRow>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final createdAt = _parseDateTime(data['createdAt']);

        if (createdAt.isBefore(range.start) || !createdAt.isBefore(range.end)) {
          continue;
        }

        final status = (data['status'] ?? '').toString();
        final completedAt = data['completedAt'] != null ? _parseDateTime(data['completedAt']) : null;

        final loadingStartedAt = data['loadingStartedAt'] != null
            ? _parseDateTime(data['loadingStartedAt'])
            : null;
        final loadingCompletedAt = data['loadingCompletedAt'] != null
            ? _parseDateTime(data['loadingCompletedAt'])
            : null;
        final unloadingStartedAt = data['unloadingStartedAt'] != null
            ? _parseDateTime(data['unloadingStartedAt'])
            : null;
        final unloadingCompletedAt = data['unloadingCompletedAt'] != null
            ? _parseDateTime(data['unloadingCompletedAt'])
            : null;

        final distanceKm = _parseDouble(data['distance']);

        rows.add(
          _ReportBookingRow(
            bookingId: doc.id,
            status: status.isEmpty ? 'unknown' : status,
            createdAt: createdAt,
            completedAt: completedAt,
            distanceKm: distanceKm,
            loadingDuration: _safeDuration(loadingStartedAt, loadingCompletedAt, now),
            unloadingDuration: _safeDuration(unloadingStartedAt, unloadingCompletedAt, now),
          ),
        );
      }

      rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _rows = [];
        _isLoading = false;
      });
    }
  }

  int get _completedCount =>
      _rows.where((r) => r.status == 'completed' || r.status == 'delivered').length;

  int get _cancelledCount => _rows
      .where((r) => r.status == 'cancelled' || r.status == 'cancelled_by_rider' || r.status == 'rejected')
      .length;

  double get _totalDistance => _rows.fold<double>(0.0, (sum, r) => sum + r.distanceKm);

  Duration get _totalLoading =>
      _rows.fold<Duration>(Duration.zero, (sum, r) => sum + r.loadingDuration);

  Duration get _totalUnloading =>
      _rows.fold<Duration>(Duration.zero, (sum, r) => sum + r.unloadingDuration);

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  String _formatStatus(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'arrived_at_pickup':
        return 'Arrived Pickup';
      case 'loading_complete':
        return 'Loading Done';
      case 'in_progress':
      case 'in_transit':
        return 'In Transit';
      case 'arrived_at_dropoff':
        return 'Arrived Drop-off';
      case 'unloading_complete':
        return 'Unloading Done';
      case 'completed':
      case 'delivered':
        return 'Completed';
      case 'cancelled':
      case 'cancelled_by_rider':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return s;
    }
  }

  void _shareReport() {
    final range = _currentRange();
    final df = DateFormat('yyyy-MM-dd');

    final buffer = StringBuffer();
    buffer.writeln('CitiMovers Rider Report');
    buffer.writeln('Range: ${df.format(range.start)} to ${df.format(range.end.subtract(const Duration(days: 1)))}');
    buffer.writeln('Total Bookings: ${_rows.length}');
    buffer.writeln('Completed: $_completedCount');
    buffer.writeln('Cancelled/Rejected: $_cancelledCount');
    buffer.writeln('Total Distance: ${_totalDistance.toStringAsFixed(1)} km');
    buffer.writeln('Total Loading Time: ${_formatDuration(_totalLoading)}');
    buffer.writeln('Total Unloading Time: ${_formatDuration(_totalUnloading)}');
    buffer.writeln('');
    buffer.writeln('Bookings:');

    for (final r in _rows) {
      buffer.writeln(
          '- ${r.bookingId} | ${_formatStatus(r.status)} | ${df.format(r.createdAt)} | ${r.distanceKm.toStringAsFixed(1)} km');
    }

    Share.share(buffer.toString());
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final range = _currentRange();
    final df = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontFamily: 'Bold'),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _rows.isEmpty ? null : _shareReport,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        color: AppColors.primaryRed,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Range',
                    style: TextStyle(
                      fontFamily: 'Bold',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Today'),
                        selected: _range == _ReportRange.today,
                        onSelected: (_) {
                          setState(() => _range = _ReportRange.today);
                          _loadReport();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('This Week'),
                        selected: _range == _ReportRange.week,
                        onSelected: (_) {
                          setState(() => _range = _ReportRange.week);
                          _loadReport();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('This Month'),
                        selected: _range == _ReportRange.month,
                        onSelected: (_) {
                          setState(() => _range = _ReportRange.month);
                          _loadReport();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${df.format(range.start)} - ${df.format(range.end.subtract(const Duration(days: 1)))}',
                    style: const TextStyle(
                      fontFamily: 'Medium',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(child: UIHelpers.loadingIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total',
                      value: '${_rows.length}',
                      icon: Icons.list_alt,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Completed',
                      value: '$_completedCount',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Cancelled',
                      value: '$_cancelledCount',
                      icon: Icons.cancel,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Distance',
                      value: '${_totalDistance.toStringAsFixed(1)} km',
                      icon: Icons.straighten,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Loading',
                      value: _formatDuration(_totalLoading),
                      icon: Icons.timer,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Unloading',
                      value: _formatDuration(_totalUnloading),
                      icon: Icons.timer,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Bookings',
                style: TextStyle(
                  fontFamily: 'Bold',
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'No bookings in this range.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ..._rows.map((r) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.lightGrey.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (r.status == 'completed' || r.status == 'delivered')
                                ? AppColors.success
                                : (r.status == 'cancelled' ||
                                        r.status == 'cancelled_by_rider' ||
                                        r.status == 'rejected')
                                    ? AppColors.error
                                    : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.bookingId,
                                style: const TextStyle(
                                  fontFamily: 'Bold',
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatStatus(r.status)} • ${df.format(r.createdAt)} • ${r.distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontFamily: 'Regular',
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Medium',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Bold',
                    fontSize: 16,
                    color: AppColors.textPrimary,
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
