import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';

class RiderDeliveryHistoryScreen extends StatefulWidget {
  const RiderDeliveryHistoryScreen({super.key});

  @override
  State<RiderDeliveryHistoryScreen> createState() =>
      _RiderDeliveryHistoryScreenState();
}

class _RiderDeliveryHistoryScreenState
    extends State<RiderDeliveryHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'This Week',
    'This Month',
    'Last Month'
  ];

  // Data from Firebase
  List<DeliveryHistory> _deliveries = [];
  List<DeliveryHistory> _filteredDeliveries = [];
  bool _isLoading = true;
  Map<String, String> _customerNames = {}; // Cache for customer names

  @override
  void initState() {
    super.initState();
    _loadDeliveryHistory();
  }

  Future<void> _loadDeliveryHistory() async {
    final riderId = _authService.currentUser?.userId;
    if (riderId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load completed bookings for this rider
      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('driverId', isEqualTo: riderId)
          .where('status', whereIn: ['completed', 'delivered']).get();

      List<DeliveryHistory> deliveries = [];
      Map<String, String> customerNames = {};
      Map<String, double> ratings = {};

      final sorted = bookingsQuery.docs.map((doc) {
        final booking = BookingModel.fromMap({
          ...doc.data(),
          'bookingId': doc.id,
        });
        return {'doc': doc, 'booking': booking};
      }).toList();

      sorted.sort((a, b) {
        final aBooking = a['booking'] as BookingModel;
        final bBooking = b['booking'] as BookingModel;
        return bBooking.createdAt.compareTo(aBooking.createdAt);
      });

      for (final entry in sorted) {
        final doc = entry['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
        final booking = entry['booking'] as BookingModel;

        if (booking.customerName != null && booking.customerName!.isNotEmpty) {
          customerNames[booking.customerId] = booking.customerName!;
        }

        // Fetch customer name if not already cached
        if (!customerNames.containsKey(booking.customerId)) {
          final customerDoc = await _firestore
              .collection('users')
              .doc(booking.customerId)
              .get();
          if (customerDoc.exists) {
            final customer = UserModel.fromMap(customerDoc.data()!);
            customerNames[booking.customerId] = customer.name;
          }
        }

        // Fetch rating from reviews collection if not already cached
        if (!ratings.containsKey(doc.id)) {
          final reviewQuery = await _firestore
              .collection('reviews')
              .where('bookingId', isEqualTo: doc.id)
              .limit(1)
              .get();
          if (reviewQuery.docs.isNotEmpty) {
            final review = reviewQuery.docs.first.data();
            ratings[doc.id] = (review['rating'] as num?)?.toDouble() ?? 0.0;
          } else {
            ratings[doc.id] = 0.0;
          }
        }

        // Calculate distance and duration using Haversine formula
        final distance = _calculateDistance(
            booking.pickupLocation.latitude,
            booking.pickupLocation.longitude,
            booking.dropoffLocation.latitude,
            booking.dropoffLocation.longitude);
        final duration = _calculateDuration(distance);

        final delivery = DeliveryHistory(
          bookingId: doc.id,
          date: DateFormat('MMM d, yyyy').format(booking.createdAt),
          time: DateFormat('h:mm a').format(booking.createdAt),
          from: booking.pickupLocation.address,
          to: booking.dropoffLocation.address,
          distance: distance,
          duration: duration,
          fare: booking.finalFare ?? booking.estimatedFare,
          customerName: customerNames[booking.customerId] ??
              booking.customerName ??
              'Unknown',
          vehicleType: booking.vehicle.type,
          rating: ratings[doc.id] ?? 0.0,
          deliveryPhotos: booking.deliveryPhotos,
          receiverName: booking.receiverName,
        );
        deliveries.add(delivery);
      }

      setState(() {
        _deliveries = deliveries;
        _customerNames = customerNames;
        _filteredDeliveries = deliveries;
        _isLoading = false;
      });

      _applyFilter(_selectedFilter);
    } catch (e) {
      debugPrint('Error loading delivery history: $e');
      setState(() => _isLoading = false);
    }
  }

  String _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    final double c = 2 * math.asin(math.sqrt(a).clamp(0.0, 1.0));
    final double distance = earthRadius * c;
    return '${distance.toStringAsFixed(1)} km';
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  String _calculateDuration(String distanceStr) {
    // Rough estimate: 30 km/h average speed in city traffic
    final distance = double.tryParse(distanceStr.replaceAll(' km', '')) ?? 0.0;
    final hours = distance / 30;
    final minutes = (hours * 60).round();
    return '$minutes mins';
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      if (filter == 'All') {
        _filteredDeliveries = _deliveries;
      } else {
        final now = DateTime.now();
        DateTime startDate;

        switch (filter) {
          case 'This Week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            break;
          case 'This Month':
            startDate = DateTime(now.year, now.month, 1);
            break;
          case 'Last Month':
            startDate = DateTime(now.year, now.month - 1, 1);
            break;
          default:
            startDate = DateTime(2000);
        }

        _filteredDeliveries = _deliveries.where((delivery) {
          try {
            final date = DateFormat('MMM d, yyyy').parse(delivery.date);
            return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
          } catch (e) {
            return false;
          }
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Delivery History',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Summary
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
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: FontAwesomeIcons.truck,
                          value: '${_filteredDeliveries.length}',
                          label: 'Total',
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      // const SizedBox(width: 16),
                      // Expanded(
                      //   child: _StatBox(
                      //     icon: FontAwesomeIcons.pesoSign,
                      //     value:
                      //         '₱${_filteredDeliveries.fold<double>(0, (sum, item) => sum + item.fare).toStringAsFixed(0)}',
                      //     label: 'Earned',
                      //     color: AppColors.success,
                      //   ),
                      // ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatBox(
                          icon: FontAwesomeIcons.star,
                          value:
                              '${(_filteredDeliveries.isEmpty ? 0 : _filteredDeliveries.fold<double>(0, (sum, item) => sum + item.rating) / _filteredDeliveries.length).toStringAsFixed(1)}',
                          label: 'Rating',
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return GestureDetector(
                          onTap: () {
                            _applyFilter(filter);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryRed
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Bold',
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Delivery List
                Expanded(
                  child: _filteredDeliveries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No delivery history yet',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredDeliveries.length,
                          itemBuilder: (context, index) {
                            final delivery = _filteredDeliveries[index];
                            return _DeliveryHistoryCard(delivery: delivery);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class DeliveryHistory {
  final String bookingId;
  final String date;
  final String time;
  final String from;
  final String to;
  final String distance;
  final String duration;
  final double fare;
  final String customerName;
  final String vehicleType;
  final double rating;
  final Map<String, dynamic>? deliveryPhotos;
  final String? receiverName;

  DeliveryHistory({
    required this.bookingId,
    required this.date,
    required this.time,
    required this.from,
    required this.to,
    required this.distance,
    required this.duration,
    required this.fare,
    required this.customerName,
    required this.vehicleType,
    required this.rating,
    this.deliveryPhotos,
    this.receiverName,
  });
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Bold',
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryHistoryCard extends StatelessWidget {
  final DeliveryHistory delivery;

  const _DeliveryHistoryCard({required this.delivery});

  String? _getPhotoUrl(String key) {
    final photos = delivery.deliveryPhotos;
    if (photos == null) return null;
    final value = photos[key];
    if (value is String) return value;
    if (value is Map && value['url'] is String) return value['url'];
    return null;
  }

  List<MapEntry<String, String?>> _getAllPhotoUrls() {
    final photos = <MapEntry<String, String?>>[];
    final photoKeys = [
      ('Start Loading', 'start_loading'),
      ('Finish Loading', 'finish_loading'),
      ('Start Unloading', 'start_unloading'),
      ('Finish Unloading', 'finish_unloading'),
      ('Receiver ID', 'receiver_id'),
      ('Signature', 'receiver_signature'),
    ];
    for (final (label, key) in photoKeys) {
      final url = _getPhotoUrl(key);
      if (url != null && url.isNotEmpty) {
        photos.add(MapEntry(label, url));
      }
    }
    return photos;
  }

  void _viewImageFullScreen(BuildContext context, String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 50),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoGallery(BuildContext context) {
    final photos = _getAllPhotoUrls();
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos available for this delivery')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delivery Photos',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return GestureDetector(
                        onTap: () => _viewImageFullScreen(context, photo.value, photo.key),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lightGrey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Image.network(
                                    photo.value!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: AppColors.primaryRed,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.scaffoldBackground,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: AppColors.textSecondary,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  color: AppColors.scaffoldBackground,
                                  child: Text(
                                    photo.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Medium',
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoCount = _getAllPhotoUrls().length;
    final hasReceiverName = delivery.receiverName != null && delivery.receiverName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                delivery.bookingId,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date & Time
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '${delivery.date} • ${delivery.time}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Regular',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Locations
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 30,
                    color: AppColors.lightGrey,
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.from,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      delivery.to,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Details
          Row(
            children: [
              _DetailChip(
                icon: Icons.straighten,
                text: delivery.distance,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.access_time,
                text: delivery.duration,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.local_shipping,
                text: delivery.vehicleType,
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Customer & Receiver Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasReceiverName) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Receiver',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delivery.receiverName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Medium',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        delivery.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // View Photos Button
          if (photoCount > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showPhotoGallery(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View $photoCount Photo${photoCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Medium',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
