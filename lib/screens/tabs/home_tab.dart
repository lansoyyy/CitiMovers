import 'dart:async';
import 'package:citimovers/screens/tabs/notifications_tab.dart';
import 'package:citimovers/screens/tabs/bookings_tab.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/ui_helpers.dart';
import '../booking/booking_start_screen.dart';
import '../../models/location_model.dart';
import '../../models/booking_model.dart';
import '../../models/saved_location_model.dart' as app_models;
import '../../models/promo_banner_model.dart';
import '../../models/user_model.dart';
import '../why_choose_us_screen.dart';
import '../../services/auth_service.dart';
import '../../services/saved_location_service.dart';
import '../../services/promo_banner_service.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final PageController _pageController = PageController();
  int _currentCarouselIndex = 0;
  Timer? _timer;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  UserModel? _currentUser;

  // Firebase data streams
  Stream<List<PromoBanner>> get _promoBannersStream =>
      PromoBannerService.instance.getActivePromoBanners();
  Stream<List<app_models.SavedLocation>> get _savedLocationsStream =>
      SavedLocationService.instance.getUserSavedLocations(
        _authService.currentUser?.userId ?? '',
      );
  Stream<List<BookingModel>> get _recentBookingsStream =>
      BookingService().getCustomerBookings(
        _authService.currentUser?.userId ?? '',
      );

  // Unread notifications count stream
  Stream<int> get _unreadCountStream =>
      _notificationService.getUnreadNotificationsCount(
        _authService.currentUser?.userId ?? '',
        'customer',
      );

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _startAutoPlay(3); // Default to 3 for initial load
  }

  void _startAutoPlay(int pageCount) {
    _timer?.cancel();
    if (pageCount <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentCarouselIndex < pageCount - 1) {
        _currentCarouselIndex++;
      } else {
        _currentCarouselIndex = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentCarouselIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, ${_currentUser?.name ?? 'User'}! 👋',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontFamily: 'Bold',
                                        color: AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ready for your next delivery?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'Regular',
                                        color: AppColors.textSecondary,
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
                    ),
                    StreamBuilder<int>(
                      stream: _unreadCountStream,
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationsTab(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryRed.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.primaryRed,
                                  size: 24,
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        unreadCount > 9
                                            ? '9+'
                                            : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 10,
                                          fontFamily: 'Bold',
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Promo Carousel
              StreamBuilder<List<PromoBanner>>(
                stream: _promoBannersStream,
                builder: (context, snapshot) {
                  final banners = snapshot.data ?? [];

                  // Start auto-play when data is available
                  if (snapshot.hasData && banners.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_currentCarouselIndex >= banners.length) {
                        _currentCarouselIndex = 0;
                      }
                      _startAutoPlay(banners.length);
                    });
                  }

                  if (banners.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentCarouselIndex = index;
                            });
                          },
                          itemCount: banners.length,
                          itemBuilder: (context, index) {
                            final banner = banners[index];
                            return GestureDetector(
                              onTap: () {
                                if (banner.actionUrl != null) {
                                  _launchUrl(banner.actionUrl!);
                                }
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        banner.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primaryRed,
                                                  AppColors.primaryRed
                                                      .withOpacity(0.7),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.local_shipping,
                                                    color: AppColors.white,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    banner.title,
                                                    style: const TextStyle(
                                                      color: AppColors.white,
                                                      fontSize: 18,
                                                      fontFamily: 'Bold',
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (banner.description.isNotEmpty)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.7),
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              banner.description,
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontSize: 14,
                                                fontFamily: 'Medium',
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
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

                      // Carousel Indicators
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          banners.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            width: _currentCarouselIndex == index ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: _currentCarouselIndex == index
                                  ? AppColors.primaryRed
                                  : AppColors.textHint.withOpacity(0.4),
                              boxShadow: _currentCarouselIndex == index
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryRed
                                            .withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Book Delivery Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryRed,
                        AppColors.primaryRed.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookingStartScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                        SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book Delivery Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Bold',
                                letterSpacing: 0.5,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              'Fast & reliable service',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Regular',
                                letterSpacing: 0.3,
                                height: 1.2,
                                color: AppColors.textWhite,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Quick Services
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
                          'Quick Services',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ScheduleServiceCard(
                            onTap: () {
                              _showScheduleBottomSheet(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ServiceCard(
                            icon: Icons.history,
                            title: 'History',
                            subtitle: 'View past trips',
                            color: AppColors.primaryRed,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BookingsTab(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SavedLocationsCard(
                            onTap: () {
                              _showSavedLocationsBottomSheet(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ServiceCard(
                            icon: Icons.support_agent,
                            title: 'Support',
                            subtitle: '24/7 help',
                            color: AppColors.primaryBlue,
                            onTap: () {
                              _launchPhoneSupport();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Recent Bookings
              StreamBuilder<List<BookingModel>>(
                stream: _recentBookingsStream,
                builder: (context, snapshot) {
                  final bookings = snapshot.data ?? [];
                  final recentBookings = bookings.take(2).toList();

                  if (recentBookings.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  'Recent Bookings',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'Bold',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BookingsTab(),
                                  ),
                                );
                              },
                              child: const Text(
                                'See All',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...recentBookings.map((booking) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _RecentBookingCard(
                                vehicleType: booking.vehicle.type,
                                date: _formatDate(booking.createdAt),
                                status: booking.status,
                                statusColor: _getStatusColor(booking.status),
                                from: booking.pickupLocation.address,
                                to: booking.dropoffLocation.address,
                                fare: 'P${booking.estimatedFare.toInt()}',
                              ),
                            )),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Why Choose Us
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
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Why Choose Us',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _FeatureItem(
                      icon: Icons.verified_user,
                      title: 'Verified Drivers',
                      subtitle: 'Background-checked professionals',
                      color: AppColors.primaryBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WhyChooseUsScreen(
                              title: 'Verified Drivers',
                              subtitle: 'Background-checked professionals',
                              icon: Icons.verified_user,
                              color: Colors.blue,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.track_changes,
                      title: 'Real-time Tracking',
                      subtitle: 'Track delivery every step of the way',
                      color: AppColors.primaryBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WhyChooseUsScreen(
                              title: 'Real-time Tracking',
                              subtitle: 'Track delivery every step of the way',
                              icon: Icons.track_changes,
                              color: Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.payment,
                      title: 'Secure Payment',
                      subtitle: 'Multiple safe payment options',
                      color: AppColors.primaryRed,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WhyChooseUsScreen(
                              title: 'Secure Payment',
                              subtitle: 'Multiple safe payment options',
                              icon: Icons.payment,
                              color: Colors.purple,
                            ),
                          ),
                        );
                      },
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

  // Schedule Bottom Sheet
  void _showScheduleBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScheduleBottomSheet(),
    );
  }

  // Saved Locations Bottom Sheet
  void _showSavedLocationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavedLocationsBottomSheet(),
    );
  }

  // Launch Phone Support
  void _launchPhoneSupport() async {
    final uri = Uri.parse('tel:${AppConstants.supportPhone}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      UIHelpers.showErrorToast('Could not launch phone dialer');
    }
  }

  // Launch URL
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      UIHelpers.showErrorToast('Could not launch URL');
    }
  }

  // Format date
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
      case 'in progress':
        return AppColors.primaryBlue;
      case 'cancelled':
        return AppColors.error;
      case 'pending':
        return Colors.orange;
      default:
        return AppColors.textSecondary;
    }
  }
}

// Schedule Service Card Widget
class _ScheduleServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ScheduleServiceCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryRed,
                    AppColors.primaryRed.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.schedule, color: AppColors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Schedule',
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Book for later',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Saved Locations Card Widget
class _SavedLocationsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SavedLocationsCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.location_on,
                  color: AppColors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Saved',
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Quick access',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Saved Locations Bottom Sheet Widget
class _SavedLocationsBottomSheet extends StatefulWidget {
  @override
  __SavedLocationsBottomSheetState createState() =>
      __SavedLocationsBottomSheetState();
}

class __SavedLocationsBottomSheetState
    extends State<_SavedLocationsBottomSheet> {
  late Stream<List<app_models.SavedLocation>> _savedLocationsStream;
  final String _userId = AuthService().currentUser?.userId ?? '';

  @override
  void initState() {
    super.initState();
    _savedLocationsStream =
        SavedLocationService.instance.getUserSavedLocations(_userId);
  }

  IconData _getIconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'office':
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_cart;
      case 'gym':
        return Icons.fitness_center;
      case 'hospital':
        return Icons.local_hospital;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.location_on;
    }
  }

  Color _getColorForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'home':
      case 'favorite':
        return AppColors.primaryRed;
      case 'office':
      case 'work':
        return AppColors.primaryBlue;
      case 'gym':
        return Colors.green;
      case 'shopping':
        return Colors.orange;
      default:
        return AppColors.primaryRed;
    }
  }

  // Show Add Location Dialog
  void _showAddLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddLocationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              color: AppColors.textHint.withOpacity(0.3),
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
                        AppColors.primaryBlue,
                        AppColors.primaryBlue.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.location_on,
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
                        'Saved Locations',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quick access to your frequent destinations',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<List<app_models.SavedLocation>>(
              stream: _savedLocationsStream,
              builder: (context, snapshot) {
                final locations = snapshot.data ?? [];

                if (locations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 64,
                          color: AppColors.textHint.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No saved locations yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Medium',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first location for quick access',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Regular',
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    final icon = _getIconForType(location.type);
                    final color = _getColorForType(location.type);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.lightGrey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            UIHelpers.showSuccessToast(
                                'Selected ${location.name} as destination');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        location.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Bold',
                                          color: AppColors.textPrimary,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        location.address,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'Regular',
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.textHint,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddLocationDialog(context);
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
                    Icon(
                      Icons.add,
                      size: 20,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add New Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Schedule Bottom Sheet Widget
class _ScheduleBottomSheet extends StatefulWidget {
  @override
  __ScheduleBottomSheetState createState() => __ScheduleBottomSheetState();
}

class __ScheduleBottomSheetState extends State<_ScheduleBottomSheet> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool isScheduleSet = false;

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
              color: AppColors.textHint.withOpacity(0.3),
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
                        AppColors.primaryRed.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.schedule,
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
                        'Schedule Delivery',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select date and time for your delivery',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
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
                  // Date Selection
                  const Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selectedDate != null
                            ? AppColors.primaryRed.withOpacity(0.3)
                            : AppColors.lightGrey.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        final isSelected = selectedDate != null &&
                            _isSameDay(selectedDate!, date);
                        final isToday = _isSameDay(DateTime.now(), date);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDate = date;
                              _checkScheduleComplete();
                            });
                          },
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryRed
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryRed
                                    : AppColors.lightGrey.withOpacity(0.5),
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryRed
                                            .withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isToday ? 'Today' : _getWeekday(date.weekday),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date.day.toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'Bold',
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getMonth(date.month),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Medium',
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Time Selection
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Slots Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: _getTimeSlots().length,
                    itemBuilder: (context, index) {
                      final timeSlot = _getTimeSlots()[index];
                      final isSelected = selectedTime != null &&
                          selectedTime!.hour == timeSlot.hour &&
                          selectedTime!.minute == timeSlot.minute;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTime = timeSlot;
                            _checkScheduleComplete();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryRed
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryRed
                                  : AppColors.lightGrey.withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          AppColors.primaryRed.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              _formatTime(timeSlot),
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Schedule Summary
                  if (isScheduleSet) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryRed.withOpacity(0.1),
                            AppColors.primaryRed.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryRed.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryRed,
                                  AppColors.primaryRed.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scheduled for',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Medium',
                                    color: AppColors.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatScheduleDateTime(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Bold',
                                    color: AppColors.primaryRed,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: isScheduleSet
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryRed,
                          AppColors.primaryRed.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color:
                    isScheduleSet ? null : AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isScheduleSet
                    ? [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: isScheduleSet
                    ? () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookingStartScreen(),
                          ),
                        );
                        UIHelpers.showSuccessToast(
                            'Delivery scheduled for ${_formatScheduleDateTime()}');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Continue to Booking',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: isScheduleSet ? AppColors.white : AppColors.textHint,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  List<TimeOfDay> _getTimeSlots() {
    return [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 12, minute: 0),
      const TimeOfDay(hour: 13, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 17, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 19, minute: 0),
    ];
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:00 $period';
  }

  String _formatScheduleDateTime() {
    if (selectedDate == null || selectedTime == null) return '';

    final weekday = _getWeekday(selectedDate!.weekday);
    final month = _getMonth(selectedDate!.month);
    final day = selectedDate!.day;
    final time = _formatTime(selectedTime!);

    return '$weekday, $month $day at $time';
  }

  void _checkScheduleComplete() {
    setState(() {
      isScheduleSet = selectedDate != null && selectedTime != null;
    });
  }
}

// Service Card Widget
class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryRed,
                    AppColors.primaryRed.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Recent Booking Card Widget
class _RecentBookingCard extends StatelessWidget {
  final String vehicleType;
  final String date;
  final String status;
  final Color statusColor;
  final String from;
  final String to;
  final String fare;

  const _RecentBookingCard({
    required this.vehicleType,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.from,
    required this.to,
    required this.fare,
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Column(
        children: [
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
                          AppColors.primaryBlue,
                          AppColors.primaryBlue.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.2),
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
                        vehicleType,
                        style: const TextStyle(
                          fontSize: 17,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.3,
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Medium',
                    color: statusColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: AppColors.lightGrey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.radio_button_checked,
                            size: 14,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            from,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Medium',
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            to,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Medium',
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  fare,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Bold',
                    color: AppColors.primaryBlue,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Feature Item Widget
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.primaryBlue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textHint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// Add Location Dialog Widget
class _AddLocationDialog extends StatefulWidget {
  @override
  __AddLocationDialogState createState() => __AddLocationDialogState();
}

class __AddLocationDialogState extends State<_AddLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _selectedType = 'home';

  final List<Map<String, dynamic>> _typeOptions = [
    {'icon': Icons.home, 'name': 'Home', 'value': 'home'},
    {'icon': Icons.work, 'name': 'Office', 'value': 'office'},
    {'icon': Icons.school, 'name': 'School', 'value': 'school'},
    {'icon': Icons.shopping_cart, 'name': 'Shopping', 'value': 'shopping'},
    {'icon': Icons.restaurant, 'name': 'Restaurant', 'value': 'restaurant'},
    {'icon': Icons.fitness_center, 'name': 'Gym', 'value': 'gym'},
    {'icon': Icons.local_hospital, 'name': 'Hospital', 'value': 'hospital'},
    {'icon': Icons.favorite, 'name': 'Favorite', 'value': 'favorite'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryBlue.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_location_alt,
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
                        'Add New Location',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Save a location for quick access',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Name
                  const Text(
                    'Location Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Home, Work, Gym',
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGrey.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGrey.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryBlue.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a location name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Address
                  const Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Enter complete address',
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGrey.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGrey.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryRed.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // City and Postal Code in a row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'City',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                hintText: 'City',
                                filled: true,
                                fillColor: AppColors.scaffoldBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Postal Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _postalCodeController,
                              decoration: InputDecoration(
                                hintText: 'Postal Code',
                                filled: true,
                                fillColor: AppColors.scaffoldBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Latitude and Longitude
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latitude',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _latitudeController,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                hintText: '14.5995',
                                filled: true,
                                fillColor: AppColors.scaffoldBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Longitude',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Medium',
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _longitudeController,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                hintText: '120.9842',
                                filled: true,
                                fillColor: AppColors.scaffoldBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Location Type Selection
                  const Text(
                    'Location Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _typeOptions.map((option) {
                      final isSelected = _selectedType == option['value'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = option['value'];
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : AppColors.lightGrey.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                option['icon'],
                                size: 16,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                option['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Medium',
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Medium',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryBlue.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                final userId =
                                    AuthService().currentUser?.userId;
                                if (userId == null) {
                                  UIHelpers.showErrorToast(
                                      'Please login first');
                                  return;
                                }

                                // Parse coordinates
                                final latitude = double.tryParse(
                                        _latitudeController.text.trim()) ??
                                    14.5995;
                                final longitude = double.tryParse(
                                        _longitudeController.text.trim()) ??
                                    120.9842;

                                // Create new saved location
                                final newLocation = app_models.SavedLocation(
                                  id: '',
                                  userId: userId,
                                  name: _nameController.text.trim(),
                                  address: _addressController.text.trim(),
                                  latitude: latitude,
                                  longitude: longitude,
                                  type: _selectedType,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                // Save to Firestore
                                final locationId = await SavedLocationService
                                    .instance
                                    .addSavedLocation(newLocation);

                                if (locationId != null) {
                                  Navigator.pop(context);
                                  UIHelpers.showSuccessToast(
                                      'Location "${newLocation.name}" added successfully');
                                } else {
                                  UIHelpers.showErrorToast(
                                      'Failed to add location');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Bold',
                                color: AppColors.white,
                              ),
                            ),
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
      ),
    );
  }
}
