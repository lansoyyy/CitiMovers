import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Regular',
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(isUnreadOnly: false),
          _buildNotificationsList(isUnreadOnly: true),
        ],
      ),
    );
  }

  Widget _buildNotificationsList({required bool isUnreadOnly}) {
    if (_isLoading) {
      return Center(child: UIHelpers.loadingIndicator());
    }

    // Sample notification data
    final List<NotificationData> notifications =
        _getNotifications(isUnreadOnly);

    if (notifications.isEmpty) {
      return _buildEmptyState(isUnreadOnly);
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return NotificationCard(
            notification: notifications[index],
            onTap: () {
              if (notifications[index].isUnread) {
                setState(() {
                  notifications[index].isUnread = false;
                });
              }
              _handleNotificationTap(notifications[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUnreadOnly) {
    String title;
    String subtitle;
    IconData icon;

    if (isUnreadOnly) {
      title = 'No unread notifications';
      subtitle = 'You\'re all caught up!';
      icon = Icons.mark_email_read_outlined;
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

  List<NotificationData> _getNotifications(bool isUnreadOnly) {
    final allNotifications = [
      NotificationData(
        id: 'n1',
        title: 'Booking Confirmed',
        message:
            'Your booking #BK001 has been confirmed. Driver is on the way.',
        time: '2 minutes ago',
        type: NotificationType.booking,
        isUnread: true,
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      NotificationData(
        id: 'n2',
        title: 'Driver Assigned',
        message:
            'Juan Dela Cruz has been assigned to your delivery. Rating: 4.8',
        time: '5 minutes ago',
        type: NotificationType.driver,
        isUnread: true,
        icon: Icons.person_outline,
        color: AppColors.primaryBlue,
      ),
      NotificationData(
        id: 'n3',
        title: 'Promo Alert',
        message: 'Get 20% off on your next booking! Use code: CITI20',
        time: '1 hour ago',
        type: NotificationType.promo,
        isUnread: true,
        icon: Icons.local_offer,
        color: AppColors.warning,
      ),
      NotificationData(
        id: 'n4',
        title: 'Delivery Completed',
        message: 'Your delivery #BK003 has been completed successfully.',
        time: '2 hours ago',
        type: NotificationType.booking,
        isUnread: false,
        icon: Icons.task_alt_outlined,
        color: AppColors.success,
      ),
      NotificationData(
        id: 'n5',
        title: 'Payment Processed',
        message: 'Payment of ₱850 for booking #BK001 has been processed.',
        time: '3 hours ago',
        type: NotificationType.payment,
        isUnread: false,
        icon: Icons.payment_outlined,
        color: AppColors.primaryRed,
      ),
      NotificationData(
        id: 'n6',
        title: 'Rate Your Driver',
        message:
            'How was your experience with Maria Reyes? Rate your driver now.',
        time: 'Yesterday',
        type: NotificationType.review,
        isUnread: false,
        icon: Icons.star_outline,
        color: Colors.amber,
      ),
      NotificationData(
        id: 'n7',
        title: 'System Update',
        message: 'App maintenance scheduled for tonight 11:00 PM - 1:00 AM.',
        time: '2 days ago',
        type: NotificationType.system,
        isUnread: false,
        icon: Icons.system_update_outlined,
        color: AppColors.textSecondary,
      ),
    ];

    if (isUnreadOnly) {
      return allNotifications.where((n) => n.isUnread).toList();
    }

    return allNotifications;
  }

  void _handleNotificationTap(NotificationData notification) {
    switch (notification.type) {
      case NotificationType.booking:
        UIHelpers.showInfoToast('Opening booking details...');
        break;
      case NotificationType.driver:
        UIHelpers.showInfoToast('Opening driver profile...');
        break;
      case NotificationType.promo:
        UIHelpers.showInfoToast('Applying promo code...');
        break;
      case NotificationType.payment:
        UIHelpers.showInfoToast('Opening payment history...');
        break;
      case NotificationType.review:
        UIHelpers.showInfoToast('Opening review screen...');
        break;
      case NotificationType.system:
        UIHelpers.showInfoToast('System notification');
        break;
    }
  }

  void _markAllAsRead() {
    UIHelpers.showSuccessToast('All notifications marked as read');
    setState(() {
      // In a real app, this would update the backend
    });
  }

  void _clearAllNotifications() {
    UIHelpers.showSuccessToast('All notifications cleared');
    setState(() {
      // In a real app, this would update the backend
    });
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationData notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      Text(
                        notification.time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationData {
  final String id;
  final String title;
  final String message;
  final String time;
  final NotificationType type;
  final IconData icon;
  final Color color;
  bool isUnread;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    required this.icon,
    required this.color,
    this.isUnread = false,
  });
}

enum NotificationType {
  booking,
  driver,
  promo,
  payment,
  review,
  system,
}
