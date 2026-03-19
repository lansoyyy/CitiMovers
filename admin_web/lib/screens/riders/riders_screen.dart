import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class RidersScreen extends StatefulWidget {
  const RidersScreen({super.key});

  @override
  State<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends State<RidersScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = '';

  final _statusOptions = ['All', 'pending', 'active', 'suspended', 'rejected'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filter(List<QueryDocumentSnapshot> docs) {
    var result = docs;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((d) {
        final data = AdminRepository.normalizeRiderData(
          d.id,
          d.data() as Map<String, dynamic>,
        );
        final name = (data['name'] ?? '').toString().toLowerCase();
        final phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
        final plate = (data['plateNumber'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || plate.contains(q);
      }).toList();
    }
    return result;
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
                hint: 'Search by name, phone, plate',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(width: 12),
              // Status filter chips
              Wrap(
                spacing: 8,
                children: _statusOptions.map((s) {
                  final selected =
                      (s == 'All' && _statusFilter.isEmpty) ||
                      s == _statusFilter;
                  return FilterChip(
                    label: Text(s, style: GoogleFonts.inter(fontSize: 12)),
                    selected: selected,
                    selectedColor: AdminTheme.primary.withOpacity(0.15),
                    checkmarkColor: AdminTheme.primary,
                    onSelected: (_) =>
                        setState(() => _statusFilter = s == 'All' ? '' : s),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AdminRepository.streamRiders(
                statusFilter: _statusFilter.isEmpty ? null : _statusFilter,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = _filter(snap.data?.docs ?? []);
                if (docs.isEmpty) {
                  return const EmptyState(
                    message: 'No riders found',
                    icon: Icons.local_shipping_outlined,
                  );
                }
                return Card(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminTheme.divider),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = AdminRepository.normalizeRiderData(
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      );
                      final name = d['name'] ?? 'Unknown Rider';
                      final phone = d['phoneNumber'] ?? '';
                      final plate = d['plateNumber'] ?? '';
                      final vehicleType =
                          d['vehicleType'] ?? d['truckType'] ?? '';
                      final status = d['accountStatus'] ?? 'active';
                      final isOnline = d['isOnline'] == true;

                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: AdminTheme.primary.withOpacity(
                                0.1,
                              ),
                              child: Text(
                                (name as String).isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'R',
                                style: GoogleFonts.inter(
                                  color: AdminTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: AdminTheme.statusActive,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '$phone  ·  $vehicleType'
                          '${plate.isNotEmpty ? '  ·  $plate' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AdminTheme.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOnline)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AdminTheme.statusActive.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Online',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AdminTheme.statusActive,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            StatusBadge(status),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right,
                              color: AdminTheme.textSecondary,
                            ),
                          ],
                        ),
                        onTap: () => context.go('/riders/${doc.id}'),
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
