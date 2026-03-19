import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _label(String s) => s.replaceAll('_', ' ').toUpperCase();

  (Color, Color) _colors(String s) {
    switch (s) {
      case 'completed':
        return (const Color(0xFF065F46), const Color(0xFFD1FAE5));
      case 'pending':
      case 'awaiting_payment':
      case 'payment_locked':
        return (const Color(0xFF92400E), const Color(0xFFFEF3C7));
      case 'accepted':
      case 'arrived_at_pickup':
      case 'arrived_at_dropoff':
      case 'in_transit':
      case 'loading_complete':
      case 'unloading_complete':
        return (const Color(0xFF1E40AF), const Color(0xFFDBEAFE));
      case 'cancelled':
      case 'cancelled_by_rider':
      case 'cancelled_by_customer':
        return (const Color(0xFF991B1B), const Color(0xFFFEE2E2));
      case 'loading':
      case 'unloading':
        return (const Color(0xFF7C3AED), const Color(0xFFEDE9FE));
      case 'active':
      case 'approved':
      case 'paid':
      case 'sent':
        return (const Color(0xFF065F46), const Color(0xFFD1FAE5));
      case 'suspended':
      case 'failed':
      case 'rejected':
        return (const Color(0xFF991B1B), const Color(0xFFFEE2E2));
      case 'held':
      case 'queued':
      case 'flagged':
      case 'review_required':
      case 'admin_review_required':
        return (const Color(0xFF92400E), const Color(0xFFFEF3C7));
      case 'refunded':
        return (const Color(0xFF0F766E), const Color(0xFFCCFBF1));
      default:
        return (AdminTheme.textSecondary, AdminTheme.surface);
    }
  }
}
