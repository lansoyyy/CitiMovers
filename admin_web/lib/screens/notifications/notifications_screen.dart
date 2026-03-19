import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/common_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String targetType = 'all_customers';

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setSt) {
              return AlertDialog(
                title: const Text('Send Broadcast Notification'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Message body',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: targetType,
                        decoration: const InputDecoration(
                          labelText: 'Audience',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all_customers',
                            child: Text('All Customers'),
                          ),
                          DropdownMenuItem(
                            value: 'all_riders',
                            child: Text('All Riders'),
                          ),
                        ],
                        onChanged: (v) =>
                            setSt(() => targetType = v ?? 'all_customers'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Send'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!confirmed ||
        titleCtrl.text.trim().isEmpty ||
        bodyCtrl.text.trim().isEmpty) {
      return;
    }

    final sentCount = await AdminRepository.sendBroadcastNotifications(
      targetType: targetType,
      title: titleCtrl.text.trim(),
      message: bodyCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent to $sentCount ${targetType.replaceAll('_', ' ')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _sendBroadcast,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Send Broadcast'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    labelColor: AdminTheme.primary,
                    unselectedLabelColor: AdminTheme.textSecondary,
                    indicatorColor: AdminTheme.primary,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Recent Notifications'),
                      Tab(text: 'Email Queue'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [_RecentNotificationsTab(), _EmailQueueTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentNotificationsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamRecentNotifications(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No notifications',
            icon: Icons.notifications_none_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final ts = AdminRepository.parseTimestamp(d['createdAt']);
            final isRead = d['isRead'] == true;
            return ListTile(
              dense: true,
              leading: Icon(
                isRead ? Icons.notifications_none : Icons.notifications,
                color: isRead ? AdminTheme.textSecondary : AdminTheme.primary,
                size: 20,
              ),
              title: Text(
                d['title'] ?? '—',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
              subtitle: Text(
                d['body'] ?? d['message'] ?? '',
                style: GoogleFonts.inter(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: ts != null
                  ? Text(
                      DateFormat('MMM d, h:mm a').format(ts),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AdminTheme.textSecondary,
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _EmailQueueTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamEmailNotifications(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No email queued',
            icon: Icons.email_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final sent = d['isSent'] == true || d['sent'] == true;
            final ts = AdminRepository.parseTimestamp(d['createdAt']);
            return ListTile(
              dense: true,
              leading: Icon(
                sent ? Icons.mark_email_read_outlined : Icons.email_outlined,
                color: sent
                    ? AdminTheme.statusActive
                    : AdminTheme.statusPending,
              ),
              title: Text(
                d['subject'] ?? d['template'] ?? '—',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              subtitle: Text(
                d['to'] ?? d['email'] ?? '—',
                style: GoogleFonts.inter(fontSize: 11),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sent
                          ? AdminTheme.statusActive.withOpacity(0.1)
                          : AdminTheme.statusPending.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sent ? 'Sent' : 'Queued',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: sent
                            ? AdminTheme.statusActive
                            : AdminTheme.statusPending,
                      ),
                    ),
                  ),
                  if (ts != null)
                    Text(
                      DateFormat('MMM d').format(ts),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
