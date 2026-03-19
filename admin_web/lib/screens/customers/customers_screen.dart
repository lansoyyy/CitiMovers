import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filter(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final q = _searchQuery.toLowerCase();
    return docs.where((d) {
      final data = AdminRepository.normalizeUserData(
        d.id,
        d.data() as Map<String, dynamic>,
      );
      final name = (data['name'] ?? '').toString().toLowerCase();
      final phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SearchField(
                controller: _searchCtrl,
                hint: 'Search by name, phone, email',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AdminRepository.streamUsers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = _filter(snap.data?.docs ?? []);
                if (docs.isEmpty) {
                  return const EmptyState(
                      message: 'No customers found',
                      icon: Icons.people_outlined);
                }
                return Card(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminTheme.divider),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = AdminRepository.normalizeUserData(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      );
                      final name = d['name'] ?? 'Unknown';
                      final phone = d['phoneNumber'] ?? '';
                      final email = d['email'] ?? '';
                      final balance = d['walletBalance'] ?? 0;
                      final status =
                          d['isSuspended'] == true ? 'suspended' : 'active';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AdminTheme.primary.withOpacity(0.1),
                          child: Text(
                            (name as String).isNotEmpty
                                ? name[0].toUpperCase()
                                : 'C',
                            style: GoogleFonts.inter(
                                color: AdminTheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        title: Text(name,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        subtitle: Text('$phone  ·  $email',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AdminTheme.textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₱ ${balance.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AdminTheme.primary)),
                            const SizedBox(width: 12),
                            StatusBadge(status),
                            const SizedBox(width: 12),
                            const Icon(Icons.chevron_right,
                                color: AdminTheme.textSecondary),
                          ],
                        ),
                        onTap: () => context.go('/customers/${doc.id}'),
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
