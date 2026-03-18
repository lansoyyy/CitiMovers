import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/common_widgets.dart';

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AdminRepository.streamAuditLogs(limit: 200),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const EmptyState(
                      message: 'No audit logs yet',
                      icon: Icons.history_outlined);
                }
                return Card(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminTheme.divider),
                    itemBuilder: (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final action = (d['action'] ?? '—')
                          .toString()
                          .replaceAll('_', ' ');
                      final entityType = (d['entityType'] ?? '').toString();
                      final entityId = (d['entityId'] ?? '').toString();
                      final reason = (d['reason'] ?? '').toString();
                      final ts = AdminRepository.parseTimestamp(
                          d['timestamp'] ?? d['createdAt']);

                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AdminTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.history,
                              size: 18, color: AdminTheme.primary),
                        ),
                        title: Text(action.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$entityType: $entityId',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AdminTheme.textSecondary),
                            ),
                            if (reason.isNotEmpty)
                              Text(
                                reason,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: AdminTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: ts != null
                            ? Text(
                                DateFormat('MMM d, h:mm a').format(ts),
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AdminTheme.textSecondary),
                              )
                            : null,
                        isThreeLine: reason.isNotEmpty,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
