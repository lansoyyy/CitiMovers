import 'package:flutter/material.dart';
import '../models/support_ticket_model.dart';
import '../utils/app_colors.dart';

/// Shared status banner for customer and rider ticket detail screens.
class SupportTicketStatusBanner extends StatelessWidget {
  final SupportTicketModel ticket;

  const SupportTicketStatusBanner({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    if (ticket.isResolved) {
      return _Banner(
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_outline,
        text: ticket.resolutionNotes?.isNotEmpty == true
            ? 'Resolved: ${ticket.resolutionNotes}'
            : 'This ticket has been resolved.',
      );
    }

    if (ticket.isEscalatedStatus) {
      return _Banner(
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_outlined,
        text: ticket.escalationRemarks?.isNotEmpty == true
            ? 'Escalated: ${ticket.escalationRemarks}'
            : ticket.status == 'escalated_presidential'
                ? 'This ticket has been escalated to presidential review.'
                : 'This ticket has been escalated for further review.',
      );
    }

    if (ticket.status == 'pending') {
      return _Banner(
        color: const Color(0xFFF59E0B),
        icon: Icons.hourglass_top_outlined,
        text: 'Awaiting response from our support team.',
      );
    }

    if (ticket.status == 'open') {
      return _Banner(
        color: AppColors.primaryBlue,
        icon: Icons.support_agent_outlined,
        text: 'Our support team has responded. You can reply below.',
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Medium',
                color: color,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip label/color helpers for ticket list screens.
class SupportTicketStatusUi {
  SupportTicketStatusUi._();

  static String label(String status) {
    switch (status) {
      case 'resolved':
        return 'Resolved';
      case 'pending':
        return 'Pending';
      case 'open':
        return 'Open';
      case 'escalated':
      case 'escalated_manager':
        return 'Escalated';
      case 'escalated_presidential':
        return 'Presidential';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'open':
        return AppColors.primaryBlue;
      case 'escalated':
      case 'escalated_manager':
      case 'escalated_presidential':
        return const Color(0xFFF97316);
      default:
        return AppColors.textSecondary;
    }
  }
}
