import 'package:flutter/material.dart';
import '../../models/rider_notification_model.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';

class RiderNotificationsTab extends StatefulWidget {
  const RiderNotificationsTab({super.key});

  @override
  State<RiderNotificationsTab> createState() => _RiderNotificationsTabState();
}

class _RiderNotificationsTabState extends State<RiderNotificationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<RiderNotificationModel> _allNotifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _allNotifications = _getSampleNotifications();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textSecondary,
            ),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              } else if (value == 'clear_all') {
                _clearAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all_outlined),
                    SizedBox(width: 8),
                    Text('Clear all'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryRed,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Medium',
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Regular',
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Bookings'),
            Tab(text: 'Earnings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(filterType: null),
          _buildNotificationsList(filterType: RiderNotificationType.newBooking),
          _buildNotificationsList(
              filterType: RiderNotificationType.earningUpdate),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNotificationFilterDialog();
        },
        backgroundColor: AppColors.primaryRed,
        child: const Icon(
          Icons.filter_list,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildNotificationsList({RiderNotificationType? filterType}) {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    List<RiderNotificationModel> notifications = _allNotifications;

    // Apply filter if specified
    if (filterType != null) {
      notifications = notifications
          .where((n) => _isNotificationOfType(n, filterType))
          .toList();
    }

    if (notifications.isEmpty) {
      return _buildEmptyState(filterType);
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return RiderNotificationCard(
            notification: notifications[index],
            onTap: () {
              if (notifications[index].isUnread) {
                setState(() {
                  notifications[index].isUnread = false;
                });
              }
              _handleNotificationTap(notifications[index]);
            },
            onDismiss: () {
              setState(() {
                _allNotifications.remove(notifications[index]);
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(RiderNotificationType? filterType) {
    String title;
    String subtitle;
    IconData icon;

    if (filterType == RiderNotificationType.newBooking) {
      title = 'No booking notifications';
      subtitle = 'You\'ll see new booking requests here';
      icon = Icons.local_shipping_outlined;
    } else if (filterType == RiderNotificationType.earningUpdate) {
      title = 'No earning notifications';
      subtitle = 'Your earnings updates will appear here';
      icon = Icons.account_balance_wallet_outlined;
    } else {
      title = 'No notifications yet';
      subtitle = 'We\'ll notify you when something important happens';
      icon = Icons.notifications_off_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _isNotificationOfType(
      RiderNotificationModel notification, RiderNotificationType type) {
    switch (type) {
      case RiderNotificationType.newBooking:
        return notification.type == RiderNotificationType.newBooking ||
            notification.type == RiderNotificationType.bookingAccepted ||
            notification.type == RiderNotificationType.bookingCancelled ||
            notification.type == RiderNotificationType.pickupConfirmed ||
            notification.type == RiderNotificationType.deliveryCompleted;
      case RiderNotificationType.earningUpdate:
        return notification.type == RiderNotificationType.earningUpdate ||
            notification.type == RiderNotificationType.paymentReceived ||
            notification.type == RiderNotificationType.ratingReceived;
      default:
        return notification.type == type;
    }
  }

  List<RiderNotificationModel> _getSampleNotifications() {
    return [
      RiderNotificationModel(
        id: 'r1',
        title: 'New Booking Request',
        message:
            'Customer John Doe requested a delivery from Makati to Pasig. Distance: 8.5 km',
        time: '2 minutes ago',
        type: RiderNotificationType.newBooking,
        icon: RiderNotificationType.newBooking.defaultIcon,
        color: RiderNotificationType.newBooking.defaultColor,
        isUnread: true,
        bookingId: 'BK001',
        customerId: 'CUST001',
        customerName: 'John Doe',
        pickupAddress: 'Makati City',
        deliveryAddress: 'Pasig City',
        amount: 250.0,
      ),
      RiderNotificationModel(
        id: 'r2',
        title: 'Pickup Confirmed',
        message:
            'You have confirmed pickup for booking #BK001. Proceed to pickup location.',
        time: '15 minutes ago',
        type: RiderNotificationType.pickupConfirmed,
        icon: RiderNotificationType.pickupConfirmed.defaultIcon,
        color: RiderNotificationType.pickupConfirmed.defaultColor,
        isUnread: true,
        bookingId: 'BK001',
      ),
      RiderNotificationModel(
        id: 'r3',
        title: 'Delivery Completed',
        message:
            'Great job! You completed delivery #BK002. Customer rated you 5 stars.',
        time: '1 hour ago',
        type: RiderNotificationType.deliveryCompleted,
        icon: RiderNotificationType.deliveryCompleted.defaultIcon,
        color: RiderNotificationType.deliveryCompleted.defaultColor,
        isUnread: false,
        bookingId: 'BK002',
        amount: 180.0,
      ),
      RiderNotificationModel(
        id: 'r4',
        title: 'Payment Received',
        message:
            'Payment of ₱250.00 for booking #BK001 has been credited to your wallet.',
        time: '2 hours ago',
        type: RiderNotificationType.paymentReceived,
        icon: RiderNotificationType.paymentReceived.defaultIcon,
        color: RiderNotificationType.paymentReceived.defaultColor,
        isUnread: false,
        bookingId: 'BK001',
        amount: 250.0,
      ),
      RiderNotificationModel(
        id: 'r5',
        title: 'Daily Earnings Update',
        message:
            'You earned ₱1,250 today from 5 deliveries. Keep up the great work!',
        time: '3 hours ago',
        type: RiderNotificationType.earningUpdate,
        icon: RiderNotificationType.earningUpdate.defaultIcon,
        color: RiderNotificationType.earningUpdate.defaultColor,
        isUnread: false,
        amount: 1250.0,
      ),
      RiderNotificationModel(
        id: 'r6',
        title: 'Rating Received',
        message:
            'Customer Maria Reyes rated you 4.8 stars for excellent service.',
        time: '5 hours ago',
        type: RiderNotificationType.ratingReceived,
        icon: RiderNotificationType.ratingReceived.defaultIcon,
        color: RiderNotificationType.ratingReceived.defaultColor,
        isUnread: false,
        customerId: 'CUST002',
        customerName: 'Maria Reyes',
      ),
      RiderNotificationModel(
        id: 'r7',
        title: 'System Maintenance',
        message:
            'App scheduled maintenance tonight 11:00 PM - 1:00 AM. Please complete ongoing deliveries.',
        time: 'Yesterday',
        type: RiderNotificationType.maintenance,
        icon: RiderNotificationType.maintenance.defaultIcon,
        color: RiderNotificationType.maintenance.defaultColor,
        isUnread: false,
      ),
      RiderNotificationModel(
        id: 'r8',
        title: 'Weekend Bonus',
        message:
            'Earn 20% extra on all deliveries this weekend! Maximum bonus: ₱500/day.',
        time: '2 days ago',
        type: RiderNotificationType.promotion,
        icon: RiderNotificationType.promotion.defaultIcon,
        color: RiderNotificationType.promotion.defaultColor,
        isUnread: false,
      ),
    ];
  }

  void _handleNotificationTap(RiderNotificationModel notification) {
    switch (notification.type) {
      case RiderNotificationType.newBooking:
      case RiderNotificationType.bookingAccepted:
      case RiderNotificationType.bookingCancelled:
      case RiderNotificationType.pickupConfirmed:
      case RiderNotificationType.deliveryCompleted:
        UIHelpers.showInfoToast('Opening booking details...');
        break;
      case RiderNotificationType.paymentReceived:
      case RiderNotificationType.earningUpdate:
        UIHelpers.showInfoToast('Opening earnings details...');
        break;
      case RiderNotificationType.ratingReceived:
        UIHelpers.showInfoToast('Opening rating details...');
        break;
      case RiderNotificationType.promotion:
        UIHelpers.showInfoToast('Viewing promotion details...');
        break;
      case RiderNotificationType.maintenance:
      case RiderNotificationType.systemAlert:
        UIHelpers.showInfoToast('System notification');
        break;
      case RiderNotificationType.emergency:
        UIHelpers.showErrorToast('Emergency alert - Please check immediately');
        break;
    }
  }

  void _markAllAsRead() {
    UIHelpers.showSuccessToast('All notifications marked as read');
    setState(() {
      for (var notification in _allNotifications) {
        notification.isUnread = false;
      }
    });
  }

  void _clearAllNotifications() {
    UIHelpers.showSuccessToast('All notifications cleared');
    setState(() {
      _allNotifications.clear();
    });
  }

  void _showNotificationFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select notification types to display:'),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('New Bookings'),
                value: true,
                onChanged: (bool? value) {},
              ),
              CheckboxListTile(
                title: const Text('Payment Updates'),
                value: true,
                onChanged: (bool? value) {},
              ),
              CheckboxListTile(
                title: const Text('System Alerts'),
                value: false,
                onChanged: (bool? value) {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                UIHelpers.showSuccessToast('Filter applied');
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }
}

class RiderNotificationCard extends StatelessWidget {
  final RiderNotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const RiderNotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onDismiss?.call();
      },
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: AppColors.white,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isUnread
              ? AppColors.primaryRed.withOpacity(0.05)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: notification.isUnread
              ? Border.all(color: AppColors.primaryRed.withOpacity(0.2))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notification.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Notification Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily:
                                      notification.isUnread ? 'Bold' : 'Medium',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (notification.isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              notification.time,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Regular',
                                color: AppColors.textHint,
                              ),
                            ),
                            if (notification.amount != null) ...[
                              const Spacer(),
                              Text(
                                '₱${notification.amount!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Medium',
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
