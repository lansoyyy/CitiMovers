import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/support_ticket_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/support_ticket_service.dart';
import '../../../utils/app_colors.dart';
import 'new_ticket_screen.dart';
import 'ticket_detail_screen.dart';

/// Customer support tickets list screen.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view support tickets.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Support Tickets',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryRed,
          tabs: const [Tab(text: 'Active'), Tab(text: 'Resolved')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewTicketScreen(
                userId: user.userId,
                userName: user.name,
                userType: 'customer',
              ),
            ),
          );
        },
        backgroundColor: AppColors.primaryRed,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text('New Ticket',
            style: TextStyle(
                color: AppColors.white, fontFamily: 'Medium', fontSize: 14)),
      ),
      body: StreamBuilder<List<SupportTicketModel>>(
        stream: SupportTicketService().streamUserTickets(user.userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed));
          }

          final all = snap.data ?? [];
          final active = all.where((t) => t.status != 'resolved').toList();
          final resolved = all.where((t) => t.status == 'resolved').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _TicketList(tickets: active, onTap: _openDetail),
              _TicketList(tickets: resolved, onTap: _openDetail),
            ],
          );
        },
      ),
    );
  }

  void _openDetail(SupportTicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          ticket: ticket,
          currentUserId: _authService.currentUser?.userId ?? '',
          currentUserName: _authService.currentUser?.name ?? '',
          currentUserType: 'customer',
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<SupportTicketModel> tickets;
  final ValueChanged<SupportTicketModel> onTap;

  const _TicketList({required this.tickets, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(
        child: Text(
          'No tickets yet.',
          style: TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        return _TicketCard(ticket: tickets[i], onTap: () => onTap(tickets[i]));
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status);
    final statusLabel = _statusLabel(ticket.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ticket.ticketNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(width: 8),
                _catBadge(ticket.category),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Bold',
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.subject,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy h:mm a')
                  .format(ticket.updatedAt.toLocal()),
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _catBadge(String cat) {
    final isApp = cat == 'app';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isApp ? Colors.indigo : Colors.teal).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isApp ? 'App Issue' : 'Logistics',
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'Bold',
          color: isApp ? Colors.indigo : Colors.teal,
        ),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'escalated':
        return const Color(0xFFF97316);
      case 'resolved':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.textSecondary;
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'pending':
        return 'Pending';
      case 'escalated':
        return 'Escalated';
      case 'resolved':
        return 'Resolved';
      default:
        return s;
    }
  }
}
