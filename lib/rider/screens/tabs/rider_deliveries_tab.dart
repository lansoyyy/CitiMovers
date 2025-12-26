import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../../screens/delivery/delivery_tracking_screen.dart';
import '../../../models/booking_model.dart';
import '../../../models/location_model.dart';
import '../../../models/vehicle_model.dart';
import '../../services/rider_auth_service.dart';
import 'package:intl/intl.dart';

class RiderDeliveriesTab extends StatefulWidget {
  const RiderDeliveriesTab({super.key});

  @override
  State<RiderDeliveriesTab> createState() => _RiderDeliveriesTabState();
}

class _RiderDeliveriesTabState extends State<RiderDeliveriesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RiderAuthService _authService = RiderAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  List<DeliveryData> _activeDeliveries = [];
  List<DeliveryData> _completedDeliveries = [];
  List<DeliveryData> _cancelledDeliveries = [];
  List<DeliveryData> _availableDeliveries = [];

  StreamSubscription<QuerySnapshot>? _activeSubscription;
  StreamSubscription<QuerySnapshot>? _completedSubscription;
  StreamSubscription<QuerySnapshot>? _cancelledSubscription;
  StreamSubscription? _availableSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRiderDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeSubscription?.cancel();
    _completedSubscription?.cancel();
    _cancelledSubscription?.cancel();
    _availableSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRiderDeliveries() async {
    final rider = await _authService.getCurrentRider();
    if (rider != null) {
      _listenToActiveDeliveries(rider.riderId);
      _listenToCompletedDeliveries(rider.riderId);
      _listenToCancelledDeliveries(rider.riderId);
      _listenToAvailableDeliveries();
    }
  }

  void _listenToAvailableDeliveries() {
    _availableSubscription =
        _authService.getAvailableDeliveryRequests().listen((bookings) {
      if (mounted) {
        setState(() {
          _availableDeliveries = bookings
              .map((booking) =>
                  _bookingToDeliveryData(booking['bookingId'], booking))
              .toList();
        });
      }
    });
  }

  void _listenToActiveDeliveries(String riderId) {
    _activeSubscription = _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: riderId)
        .where('status',
            whereIn: ['pending', 'accepted', 'driver_assigned', 'in_progress'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _activeDeliveries = snapshot.docs
                  .map((doc) => _bookingToDeliveryData(doc.id, doc.data()))
                  .toList();
            });
          }
        });
  }

  void _listenToCompletedDeliveries(String riderId) {
    _completedSubscription = _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: riderId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _completedDeliveries = snapshot.docs
              .map((doc) => _bookingToDeliveryData(doc.id, doc.data()))
              .toList();
        });
      }
    });
  }

  void _listenToCancelledDeliveries(String riderId) {
    _cancelledSubscription = _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: riderId)
        .where('status', whereIn: ['cancelled', 'rejected'])
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _cancelledDeliveries = snapshot.docs
                  .map((doc) => _bookingToDeliveryData(doc.id, doc.data()))
                  .toList();
            });
          }
        });
  }

  DeliveryData _bookingToDeliveryData(
      String bookingId, Map<String, dynamic> data) {
    // Get vehicle data
    final vehicleData = data['vehicle'] as Map<String, dynamic>?;
    final vehicleType = vehicleData?['type'] as String? ?? '4-Wheeler';
    final vehicleCapacity = vehicleData?['capacity'] as String? ?? 'N/A';

    // Get customer info
    final customerName = data['customerName'] as String? ?? 'Unknown';
    final customerPhone = data['customerPhone'] as String? ?? 'N/A';

    // Get locations
    final pickupLocationData = data['pickupLocation'] as Map<String, dynamic>?;
    final pickupLocation = pickupLocationData?['address'] as String? ?? '';
    final deliveryLocationData =
        data['dropoffLocation'] as Map<String, dynamic>?;
    final deliveryLocation = deliveryLocationData?['address'] as String? ?? '';

    // Get date and time
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final date = DateFormat('MMM dd, yyyy').format(createdAt);
    final time = DateFormat('h:mm a').format(createdAt);

    // Get fare
    final fare =
        (data['estimatedFare'] as num? ?? data['fare'] as num? ?? 0).toDouble();
    final finalFare = (data['finalFare'] as num?)?.toDouble();

    // Get status
    final status = data['status'] as String? ?? 'pending';

    // Get status color and display text
    Color statusColor;
    String statusText;
    String estimatedTimeText;

    switch (status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Pending';
        estimatedTimeText = 'Waiting for driver';
        break;
      case 'accepted':
        statusColor = AppColors.primaryBlue;
        statusText = 'Accepted';
        estimatedTimeText = 'Preparing';
        break;
      case 'driver_assigned':
        statusColor = AppColors.warning;
        statusText = 'Driver Assigned';
        estimatedTimeText = 'Heading to pickup';
        break;
      case 'in_progress':
        statusColor = AppColors.primaryRed;
        statusText = 'In Transit';
        estimatedTimeText = 'On the way';
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusText = 'Completed';
        estimatedTimeText = 'Delivered';
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusText = 'Cancelled';
        estimatedTimeText = 'Cancelled';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'Rejected';
        estimatedTimeText = 'Rejected';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
        estimatedTimeText = 'N/A';
    }

    // Get customer rating
    final customerRating = (data['customerRating'] as num?)?.toDouble() ?? 0.0;

    // Get estimated duration
    final estimatedDuration = data['estimatedDuration'] as num? ?? 0;

    // Get payment method
    final paymentMethod = data['paymentMethod'] as String? ?? 'Cash';

    // Get notes
    final notes = data['notes'] as String?;

    // Get distance
    final distance = (data['distance'] as num?)?.toDouble() ?? 0.0;

    // Derive package type from vehicle type
    String packageType;
    switch (vehicleType) {
      case 'Motorcycle':
        packageType = 'Small Package';
        break;
      case 'Sedan':
        packageType = 'Standard Package';
        break;
      case 'AUV':
        packageType = 'Medium Package';
        break;
      case '4-Wheeler':
        packageType = 'Large Package';
        break;
      case '6-Wheeler':
        packageType = 'Extra Large Package';
        break;
      case 'Wingvan':
        packageType = 'Heavy Package';
        break;
      case 'Trailer':
        packageType = 'Oversized Package';
        break;
      case '10-Wheeler Wingvan':
        packageType = 'Industrial Package';
        break;
      default:
        packageType = 'Standard Delivery';
    }

    // Derive insurance from fare
    final actualFare = finalFare ?? fare;
    String insurance;
    if (actualFare < 500) {
      insurance = 'Basic Coverage';
    } else if (actualFare < 1000) {
      insurance = 'Standard Coverage';
    } else if (actualFare < 2000) {
      insurance = 'Premium Coverage';
    } else {
      insurance = 'Full Coverage';
    }

    return DeliveryData(
      id: bookingId,
      vehicleType: vehicleType,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: pickupLocation,
      deliveryLocation: deliveryLocation,
      date: date,
      time: time,
      fare: 'P${(finalFare ?? fare).toStringAsFixed(0)}',
      status: statusText,
      statusColor: statusColor,
      estimatedTime: estimatedDuration > 0
          ? '${estimatedDuration.toStringAsFixed(0)} mins'
          : estimatedTimeText,
      customerRating: customerRating,
      paymentMethod: paymentMethod,
      packageType: packageType,
      weight: vehicleCapacity,
      insurance: insurance,
      specialInstructions: notes ?? 'None',
      distance: distance,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
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
                  const Text(
                    'My Deliveries',
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: AppColors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(
                        fontFamily: 'Bold',
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Medium',
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'Active'),
                        Tab(text: 'Completed'),
                        Tab(text: 'Cancelled'),
                        Tab(text: 'Available'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveDeliveries(),
                  _buildCompletedDeliveries(),
                  _buildCancelledDeliveries(),
                  _buildAvailableDeliveries(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveries() {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    if (_activeDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: AppColors.lightGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go online to start receiving delivery requests',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _activeDeliveries.length,
        itemBuilder: (context, index) {
          return DeliveryCard(
            delivery: _activeDeliveries[index],
            onTap: () async {
              // Navigate to delivery tracking screen for active deliveries
              // Fetch booking details from Firestore
              final bookingDoc = await _firestore
                  .collection('bookings')
                  .doc(_activeDeliveries[index].id)
                  .get();

              if (bookingDoc.exists && context.mounted) {
                final booking = BookingModel.fromMap(bookingDoc.data()!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DeliveryTrackingScreen(booking: booking),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildCompletedDeliveries() {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    if (_completedDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.lightGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Completed Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t completed any deliveries yet',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _completedDeliveries.length,
        itemBuilder: (context, index) {
          return DeliveryCard(
            delivery: _completedDeliveries[index],
            onTap: () {
              // Show bottom sheet for completed deliveries
              _showDeliveryDetailsBottomSheet(
                  context, _completedDeliveries[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildCancelledDeliveries() {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    if (_cancelledDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 80,
              color: AppColors.lightGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Cancelled Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have any cancelled deliveries',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _cancelledDeliveries.length,
        itemBuilder: (context, index) {
          return DeliveryCard(
            delivery: _cancelledDeliveries[index],
            onTap: () {
              // Show bottom sheet for cancelled deliveries
              _showDeliveryDetailsBottomSheet(
                  context, _cancelledDeliveries[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildAvailableDeliveries() {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    if (_availableDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: AppColors.lightGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Available Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'New delivery requests will appear here',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _availableDeliveries.length,
        itemBuilder: (context, index) {
          return AvailableDeliveryCard(
            delivery: _availableDeliveries[index],
            onAccept: () => _acceptDelivery(_availableDeliveries[index]),
            onReject: () => _rejectDelivery(_availableDeliveries[index]),
          );
        },
      ),
    );
  }

  Future<void> _acceptDelivery(DeliveryData delivery) async {
    final confirmed = await _showAcceptConfirmationDialog(delivery);
    if (confirmed) {
      setState(() => _isLoading = true);
      try {
        final success = await _authService.acceptDeliveryRequest(delivery.id);
        if (success && mounted) {
          UIHelpers.showSuccessToast('Delivery accepted successfully');
          // Navigate to delivery progress screen
          final bookingDoc =
              await _firestore.collection('bookings').doc(delivery.id).get();

          if (bookingDoc.exists && mounted) {
            final booking = BookingModel.fromMap(bookingDoc.data()!);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveryTrackingScreen(booking: booking),
              ),
            );
          }
        } else if (mounted) {
          UIHelpers.showErrorToast('Failed to accept delivery');
        }
      } catch (e) {
        if (mounted) {
          UIHelpers.showErrorToast('Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> _showAcceptConfirmationDialog(DeliveryData delivery) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Accept Delivery',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogDetailRow('Vehicle Type', delivery.vehicleType),
                _buildDialogDetailRow('Pickup', delivery.pickupLocation),
                _buildDialogDetailRow('Drop-off', delivery.deliveryLocation),
                _buildDialogDetailRow('Fare', delivery.fare),
                _buildDialogDetailRow('Distance',
                    '${delivery.distance > 0 ? delivery.distance.toStringAsFixed(1) : 'N/A'} km'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Medium',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Regular',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDelivery(DeliveryData delivery) async {
    final confirmed = await _showRejectConfirmationDialog(delivery);
    if (confirmed) {
      setState(() => _isLoading = true);
      try {
        final success = await _authService.rejectDeliveryRequest(delivery.id);
        if (success && mounted) {
          UIHelpers.showSuccessToast('Delivery rejected');
        } else if (mounted) {
          UIHelpers.showErrorToast('Failed to reject delivery');
        }
      } catch (e) {
        if (mounted) {
          UIHelpers.showErrorToast('Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> _showRejectConfirmationDialog(DeliveryData delivery) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Reject Delivery',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to reject this delivery request?',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDialogDetailRow('Vehicle Type', delivery.vehicleType),
                _buildDialogDetailRow('Pickup', delivery.pickupLocation),
                _buildDialogDetailRow('Drop-off', delivery.deliveryLocation),
                _buildDialogDetailRow('Fare', delivery.fare),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Reject',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showDeliveryDetailsBottomSheet(
      BuildContext context, DeliveryData delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryDetailsBottomSheet(delivery: delivery),
    );
  }
}

class DeliveryCard extends StatelessWidget {
  final DeliveryData delivery;
  final VoidCallback onTap;

  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with vehicle type, ID and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryRed,
                                AppColors.primaryRed.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primaryRed.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              delivery.vehicleType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${delivery.id}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: delivery.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: delivery.statusColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        delivery.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Medium',
                          color: delivery.statusColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date and Time Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.date,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Medium',
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          delivery.time,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Customer Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.customerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Medium',
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            delivery.customerPhone,
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

                const SizedBox(height: 20),

                // Simplified Route
                Container(
                  padding: const EdgeInsets.all(16),
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
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'From',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              delivery.pickupLocation,
                              style: const TextStyle(
                                fontSize: 13,
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
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'To',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              delivery.deliveryLocation,
                              style: const TextStyle(
                                fontSize: 13,
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

                const SizedBox(height: 20),

                // Footer with fare and quick action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        delivery.fare,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.primaryRed,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            delivery.status == 'In Transit' ||
                                    delivery.status == 'Driver Assigned' ||
                                    delivery.status == 'Preparing'
                                ? 'Track Delivery'
                                : 'View Details',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Medium',
                              color: AppColors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvailableDeliveryCard extends StatelessWidget {
  final DeliveryData delivery;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const AvailableDeliveryCard({
    super.key,
    required this.delivery,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with vehicle type and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryRed,
                            AppColors.primaryRed.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.vehicleType,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${delivery.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Medium',
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'New Request',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Bold',
                          color: AppColors.warning,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Date and Time Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.date,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      delivery.time,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Customer Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Medium',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        delivery.customerPhone,
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

            const SizedBox(height: 20),

            // Route
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.lightGrey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Pickup
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pickup',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              delivery.pickupLocation,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Drop-off
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Drop-off',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              delivery.deliveryLocation,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Details Row
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.straighten,
                    'Distance',
                    '${delivery.distance > 0 ? delivery.distance.toStringAsFixed(1) : 'N/A'} km',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    Icons.access_time,
                    'Est. Time',
                    delivery.estimatedTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Fare and Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Earnings',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Medium',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        delivery.fare,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.primaryRed,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Reject Button
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onReject,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Reject',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Bold',
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept Button
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success,
                            AppColors.success.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onAccept,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 20,
                                  color: AppColors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Bold',
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Medium',
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryData {
  final String id;
  final String vehicleType;
  final String customerName;
  final String customerPhone;
  final String pickupLocation;
  final String deliveryLocation;
  final String date;
  final String time;
  final String fare;
  final String status;
  final Color statusColor;
  final String estimatedTime;
  final double customerRating;
  final String paymentMethod;
  final String packageType;
  final String weight;
  final String insurance;
  final String specialInstructions;
  final double distance;

  DeliveryData({
    required this.id,
    required this.vehicleType,
    required this.customerName,
    required this.customerPhone,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.date,
    required this.time,
    required this.fare,
    required this.status,
    required this.statusColor,
    required this.estimatedTime,
    required this.customerRating,
    required this.paymentMethod,
    required this.packageType,
    required this.weight,
    required this.insurance,
    required this.specialInstructions,
    required this.distance,
  });
}

// Note: BookingData is imported from bookings_tab.dart

// Delivery Details Bottom Sheet
class DeliveryDetailsBottomSheet extends StatelessWidget {
  final DeliveryData delivery;

  const DeliveryDetailsBottomSheet({
    super.key,
    required this.delivery,
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
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryRed,
                        AppColors.primaryRed.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                        delivery.vehicleType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Delivery ID: ${delivery.id}',
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
                    color: delivery.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: delivery.statusColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    delivery.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Medium',
                      color: delivery.statusColor,
                      height: 1.2,
                    ),
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
                  // Schedule Information
                  _buildSectionCard(
                    'Schedule Information',
                    Icons.calendar_today,
                    [
                      _buildDetailRow('Date', delivery.date),
                      _buildDetailRow('Time', delivery.time),
                      _buildDetailRow('Status', delivery.estimatedTime),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Customer Information
                  _buildSectionCard(
                    'Customer Information',
                    Icons.person,
                    [
                      _buildDetailRow('Name', delivery.customerName),
                      _buildDetailRow('Phone', delivery.customerPhone),
                      if (delivery.customerRating > 0)
                        _buildDetailRow(
                            'Rating', '${delivery.customerRating} ⭐'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Route Details
                  _buildRouteSection(),

                  const SizedBox(height: 20),

                  // Payment Information
                  _buildSectionCard(
                    'Payment Information',
                    Icons.payment,
                    [
                      _buildDetailRow('Total Fare', delivery.fare),
                      _buildDetailRow('Payment Method', delivery.paymentMethod),
                      _buildDetailRow('Payment Status',
                          delivery.status == 'Completed' ? 'Paid' : 'Pending'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Additional Information
                  _buildSectionCard(
                    'Additional Information',
                    Icons.info_outline,
                    [
                      _buildDetailRow('Package Type', delivery.packageType),
                      _buildDetailRow('Weight', delivery.weight),
                      _buildDetailRow('Insurance', delivery.insurance),
                      _buildDetailRow(
                          'Special Instructions', delivery.specialInstructions),
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
            child: Column(
              children: [
                // Primary Action for completed deliveries
                if (delivery.status == 'Completed') ...[
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        UIHelpers.showInfoToast(
                            'Download receipt feature coming soon');
                      },
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
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Download Receipt',
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
                  const SizedBox(height: 12),
                ],

                // Secondary Actions Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast(
                              'Contact customer feature coming soon');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.primaryRed.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone,
                              size: 18,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Contact',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          UIHelpers.showInfoToast(
                              'Support feature coming soon');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.textHint.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Support',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
            width: 100,
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
                      delivery.pickupLocation,
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
                      delivery.deliveryLocation,
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

          // Distance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.straighten,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Estimated Distance: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  delivery.distance > 0
                      ? '${delivery.distance.toStringAsFixed(1)} km'
                      : 'N/A',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Medium',
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
