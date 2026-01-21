import 'dart:async';
import 'package:citimovers/rider/screens/rider_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';
import '../profile/rider_settings_screen.dart';
import '../../models/delivery_request_model.dart';
import '../../../models/booking_model.dart';
import '../delivery/rider_delivery_progress_screen.dart';

class RiderHomeTab extends StatefulWidget {
  final TabController tabController;

  const RiderHomeTab({
    super.key,
    required this.tabController,
  });

  @override
  State<RiderHomeTab> createState() => _RiderHomeTabState();
}

class _RiderHomeTabState extends State<RiderHomeTab> {
  final _authService = RiderAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _isOnline = true;
  int _todayDeliveries = 0;
  double _todayEarnings = 0.0;
  List<DeliveryRequest> _deliveryRequests = [];
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  @override
  void initState() {
    super.initState();
    _loadRiderData();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRiderData() async {
    final rider = await _authService.getCurrentRider();
    if (mounted && rider != null) {
      setState(() {
        _isOnline = rider.isOnline;
      });

      // Listen to today's bookings for stats
      _listenToTodayStats(rider.riderId);

      // Listen to delivery requests when online
      if (_isOnline) {
        _listenToDeliveryRequests();
      }
    }
  }

  void _listenToTodayStats(String riderId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final startMs = startOfDay.millisecondsSinceEpoch;
    final endMs = endOfDay.millisecondsSinceEpoch;

    _bookingsSubscription = _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: riderId)
        .where('status', whereIn: [
          'completed',
          'arrived_at_pickup',
          'loading_complete',
          'arrived_at_dropoff',
          'unloading_complete'
        ])
        .where('createdAt', isGreaterThanOrEqualTo: startMs)
        .where('createdAt', isLessThan: endMs)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _todayDeliveries = snapshot.docs.length;
              _todayEarnings = snapshot.docs.fold<double>(
                0.0,
                (sum, doc) {
                  final data = doc.data();
                  final base = _parseDouble(data['finalFare']) > 0
                      ? _parseDouble(data['finalFare'])
                      : _parseDouble(data['estimatedFare'],
                          fallback: _parseDouble(data['fare']));
                  final loading = _parseDouble(data['loadingDemurrageFee']);
                  final unloading = _parseDouble(data['unloadingDemurrageFee']);
                  return sum + base + loading + unloading;
                },
              );
            });
          }
        });
  }

  void _listenToDeliveryRequests() {
    // Listen to bookings with status 'pending' and no driver assigned
    _requestsSubscription = _firestore
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .where('driverId', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _deliveryRequests = snapshot.docs
              .map((doc) => _bookingToDeliveryRequest(doc.id, doc.data()))
              .toList();
        });
      }
    });
  }

  DeliveryRequest _bookingToDeliveryRequest(
      String bookingId, Map<String, dynamic> data) {
    // Calculate request time
    final createdAt = _parseDateTime(data['createdAt']);
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    String requestTime;
    if (difference.inMinutes < 1) {
      requestTime = 'Just now';
    } else if (difference.inMinutes < 60) {
      requestTime = '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      requestTime = '${difference.inHours} hours ago';
    } else {
      requestTime = '${difference.inDays} days ago';
    }

    // Get customer info
    final customerName = data['customerName'] as String? ?? 'Unknown';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';

    // Get locations
    final pickupLocationRaw = data['pickupLocation'];
    final dropoffLocationRaw = data['dropoffLocation'];
    final pickupLocation = pickupLocationRaw is Map
        ? (pickupLocationRaw['address'] ?? '').toString()
        : (pickupLocationRaw ?? '').toString();
    final deliveryLocation = dropoffLocationRaw is Map
        ? (dropoffLocationRaw['address'] ?? '').toString()
        : (dropoffLocationRaw ?? '').toString();

    // Get distance and time
    final distance = _parseDouble(data['distance']);
    final estimatedDuration = _parseDouble(data['estimatedDuration']);

    // Get fare
    final fare = _parseDouble(data['finalFare']) > 0
        ? _parseDouble(data['finalFare'])
        : _parseDouble(data['estimatedFare']);

    // Get package info
    final vehicleRaw = data['vehicle'];
    final vehicleType =
        vehicleRaw is Map ? (vehicleRaw['type'] ?? '').toString() : '';
    final vehicleCapacity =
        vehicleRaw is Map ? (vehicleRaw['capacity'] ?? '').toString() : '';
    final packageType = vehicleType.isNotEmpty ? vehicleType : 'Standard';
    final weight = vehicleCapacity.isNotEmpty ? vehicleCapacity : 'N/A';
    final specialInstructions = data['notes'] as String? ?? 'None';

    // Get urgency
    final urgency = data['urgency'] as String? ?? 'Normal';

    return DeliveryRequest(
      id: bookingId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: pickupLocation,
      deliveryLocation: deliveryLocation,
      distance: '${distance.toStringAsFixed(1)} km',
      estimatedTime: '${estimatedDuration.toStringAsFixed(0)} mins',
      fare: 'P${fare.toStringAsFixed(0)}',
      packageType: packageType,
      weight: weight,
      urgency: urgency,
      specialInstructions: specialInstructions,
      requestTime: requestTime,
    );
  }

  void _showDeliveryDetailsBottomSheet(
      BuildContext context, DeliveryRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryRequestBottomSheet(
        request: request,
        onAccept: () => _acceptDelivery(request),
        onReject: () => _rejectDelivery(request),
      ),
    );
  }

  void _acceptDelivery(DeliveryRequest request) {
    Navigator.pop(context);

    _authService.acceptDeliveryRequest(request.id).then((success) {
      if (!mounted) return;
      if (!success) {
        UIHelpers.showErrorToast('Failed to accept delivery');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RiderDeliveryProgressScreen(request: request),
        ),
      );

      setState(() {
        _deliveryRequests.removeWhere((r) => r.id == request.id);
      });
    });
    // UIHelpers.showSuccessToast('Delivery request accepted! Navigate to pickup location.');
  }

  void _rejectDelivery(DeliveryRequest request) {
    Navigator.pop(context);

    _authService.rejectDeliveryRequest(request.id).then((_) {
      if (!mounted) return;
      setState(() {
        _deliveryRequests.removeWhere((r) => r.id == request.id);
      });
      UIHelpers.showInfoToast('Delivery request rejected');
    });
  }

  Future<void> _toggleOnlineStatus() async {
    final success = await _authService.toggleOnlineStatus();
    if (success && mounted) {
      setState(() {
        _isOnline = !_isOnline;
      });

      // Start or stop listening to delivery requests
      if (_isOnline) {
        _listenToDeliveryRequests();
      } else {
        _requestsSubscription?.cancel();
        setState(() {
          _deliveryRequests = [];
        });
      }

      UIHelpers.showSuccessToast(
        _isOnline ? 'You are now online' : 'You are now offline',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = _authService.currentRider;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Online/Offline Toggle
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Profile Picture
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.white,
                          child: rider?.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    rider!.photoUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.person,
                                      size: 28,
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 28,
                                  color: AppColors.primaryRed,
                                ),
                        ),
                        const SizedBox(width: 16),
                        // Rider Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${rider?.name ?? 'Rider'}! 👋',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontFamily: 'Bold',
                                  color: AppColors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${rider?.rating.toStringAsFixed(1) ?? '0.0'} rating',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Regular',
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Notification Bell
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RiderNotificationsScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Online/Offline Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _isOnline
                                      ? AppColors.success
                                      : AppColors.grey,
                                  shape: BoxShape.circle,
                                  boxShadow: _isOnline
                                      ? [
                                          BoxShadow(
                                            color: AppColors.success
                                                .withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isOnline
                                    ? 'You are Online'
                                    : 'You are Offline',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Bold',
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnline,
                            onChanged: (value) => _toggleOnlineStatus(),
                            activeColor: AppColors.success,
                            activeTrackColor:
                                AppColors.success.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Today's Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Today's Performance",
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: FontAwesomeIcons.truck,
                            title: 'Deliveries',
                            value: '$_todayDeliveries',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: FontAwesomeIcons.pesoSign,
                            title: 'Earnings',
                            value: 'P${_todayEarnings.toStringAsFixed(0)}',
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.history,
                            title: 'History',
                            subtitle: 'View past deliveries',
                            color: AppColors.primaryBlue,
                            onTap: () {
                              // Switch to deliveries tab
                              widget.tabController.animateTo(1);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.account_balance_wallet,
                            title: 'Wallet',
                            subtitle: 'Check balance',
                            color: AppColors.success,
                            onTap: () {
                              // Switch to earnings tab
                              widget.tabController.animateTo(2);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.support_agent,
                            title: 'Support',
                            subtitle: '24/7 help',
                            color: AppColors.warning,
                            onTap: () {
                              UIHelpers.showInfoToast('Coming soon');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.settings,
                            title: 'Settings',
                            subtitle: 'App preferences',
                            color: AppColors.textSecondary,
                            onTap: () {
                              // Navigate to settings screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RiderSettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Delivery Requests (if any)
              if (_isOnline)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _deliveryRequests.isEmpty
                                ? 'Waiting for Delivery Request'
                                : 'Available Delivery Requests (${_deliveryRequests.length})',
                            style: const TextStyle(
                              fontSize: 20,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_deliveryRequests.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: AppColors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Looking for nearby deliveries...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Bold',
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'You\'ll be notified when a new delivery request arrives',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'Regular',
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _deliveryRequests.map((request) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DeliveryRequestCard(
                                request: request,
                                onTap: () => _showDeliveryDetailsBottomSheet(
                                    context, request),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Delivery Request Card Widget
class DeliveryRequestCard extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onTap;

  const DeliveryRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: request.urgency == 'Urgent'
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.primaryRed.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with urgency badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.redGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: AppColors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.requestTime,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Regular',
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: request.urgency == 'Urgent'
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: request.urgency == 'Urgent'
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.primaryRed.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    request.urgency,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Bold',
                      color: request.urgency == 'Urgent'
                          ? AppColors.error
                          : AppColors.primaryRed,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.lightGrey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'From',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.pickupLocation,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'To',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.deliveryLocation,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Delivery Details Row
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: request.distance,
                  ),
                ),
                Expanded(
                  child: _DetailItem(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: request.estimatedTime,
                  ),
                ),
                Expanded(
                  child: _DetailItem(
                    icon: Icons.monetization_on,
                    label: 'Fare',
                    value: request.fare,
                    valueColor: AppColors.primaryRed,
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

// Detail Item Widget
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Regular',
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Bold',
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// Delivery Request Bottom Sheet
class DeliveryRequestBottomSheet extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const DeliveryRequestBottomSheet({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.redGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Request',
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Request ID: ${request.id}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: request.urgency == 'Urgent'
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: request.urgency == 'Urgent'
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.primaryRed.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    request.urgency,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Bold',
                      color: request.urgency == 'Urgent'
                          ? AppColors.error
                          : AppColors.primaryRed,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Information
                  _buildSectionCard(
                    'Customer Information',
                    Icons.person,
                    [
                      _buildDetailRow('Name', request.customerName),
                      _buildDetailRow('Phone', request.customerPhone),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Package Information
                  _buildSectionCard(
                    'Package Information',
                    Icons.inventory_2,
                    [
                      _buildDetailRow('Type', request.packageType),
                      _buildDetailRow('Weight', request.weight),
                      _buildDetailRow(
                          'Special Instructions', request.specialInstructions),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Route Details
                  _buildRouteSection(),

                  const SizedBox(height: 20),

                  // Delivery Details
                  _buildSectionCard(
                    'Delivery Details',
                    Icons.delivery_dining,
                    [
                      _buildDetailRow('Distance', request.distance),
                      _buildDetailRow('Estimated Time', request.estimatedTime),
                      _buildDetailRow('Fare', request.fare),
                      _buildDetailRow('Request Time', request.requestTime),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: onReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.error,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightGrey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Medium',
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightGrey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.route,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Route Details',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pickup Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.radio_button_checked,
                  size: 16,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.pickupLocation,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Route Line
          Container(
            margin: const EdgeInsets.only(left: 11),
            height: 30,
            child: const VerticalDivider(
              color: AppColors.textHint,
              thickness: 1,
            ),
          ),

          const SizedBox(height: 16),

          // Drop-off Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Drop-off Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.deliveryLocation,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Action Card Widget
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
