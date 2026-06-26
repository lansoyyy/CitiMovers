import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/rider_document_requirements.dart';
import '../../config/theme.dart';
import '../../config/app_constants.dart';
import '../../services/admin_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class RiderDetailScreen extends StatefulWidget {
  final String riderId;
  const RiderDetailScreen({super.key, required this.riderId});

  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _riderData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadRider();
  }

  Future<void> _loadRider() async {
    final riderData = await AdminRepository.getNormalizedRider(widget.riderId);
    if (!mounted) return;
    setState(() {
      _riderData = riderData;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _approveRider() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Approve Rider',
      message:
          'Approve this rider account? They will be able to receive bookings.',
      confirmLabel: 'Approve',
      confirmColor: AdminTheme.statusActive,
    );
    if (!confirmed) return;

    await AdminRepository.approveRider(widget.riderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rider approved. They can now log in to the rider app.'),
      ),
    );
    _loadRider();
  }

  Future<void> _toggleSuspend() async {
    final isSuspended = _riderData?['accountStatus'] == 'suspended';
    final action = isSuspended ? 'Reactivate' : 'Suspend';
    final confirmed = await ConfirmDialog.show(
      context,
      title: '$action Rider',
      message: 'Are you sure you want to $action this rider?',
      confirmLabel: action,
      confirmColor: isSuspended ? AdminTheme.statusActive : AdminTheme.accent,
    );
    if (!confirmed) return;

    await AdminRepository.setRiderSuspended(
      riderId: widget.riderId,
      isSuspended: !isSuspended,
    );
    _loadRider();
  }

  Future<void> _rejectDocument(String docKey, String docLabel) async {
    final reasonCtrl = TextEditingController();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Reject: $docLabel'),
            content: TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection reason (required)',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reject Document'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || reasonCtrl.text.trim().isEmpty) return;

    await AdminRepository.rejectRiderDocument(
      riderId: widget.riderId,
      docKey: docKey,
      reason: reasonCtrl.text.trim(),
    );
    _loadRider();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_riderData == null) {
      return const Center(child: Text('Rider not found.'));
    }

    final d = _riderData!;
    final name = d['name'] ?? 'Unknown Rider';
    final phone = d['phoneNumber'] ?? '';
    final vehicleType = d['vehicleType'] ?? d['truckType'] ?? '';
    final plate = d['plateNumber'] ?? '';
    final status = d['accountStatus'] ?? 'active';
    final rating = (d['averageRating'] ?? d['rating'] ?? 0).toStringAsFixed(1);
    final isPending = status == 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + actions
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go('/riders'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Riders'),
              ),
              const Spacer(),
              if (isPending)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.statusActive,
                  ),
                  onPressed: _approveRider,
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Approve Rider'),
                ),
              if (!isPending) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'suspended'
                        ? AdminTheme.statusActive
                        : AdminTheme.accent,
                  ),
                  onPressed: _toggleSuspend,
                  icon: Icon(
                    status == 'suspended' ? Icons.check_circle : Icons.block,
                    size: 16,
                  ),
                  label: Text(status == 'suspended' ? 'Reactivate' : 'Suspend'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AdminTheme.primary.withOpacity(0.1),
                    child: Text(
                      (name as String).isNotEmpty ? name[0].toUpperCase() : 'R',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AdminTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          children: [
                            _InfoChip(
                              Icons.local_shipping_outlined,
                              vehicleType,
                            ),
                            if (plate.isNotEmpty)
                              _InfoChip(Icons.pin_outlined, plate),
                            _InfoChip(Icons.star_outline, '$rating ★'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tabs
          Card(
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
                    Tab(text: 'Documents'),
                    Tab(text: 'Delivery History'),
                    Tab(text: 'Earnings'),
                  ],
                ),
                SizedBox(
                  height: 500,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _DocumentsTab(
                        riderData: _riderData!,
                        onReject: _rejectDocument,
                      ),
                      _DeliveryHistoryTab(riderId: widget.riderId),
                      _EarningsTab(riderId: widget.riderId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AdminTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AdminTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Documents Tab ────────────────────────────────────────────────────────────
class _DocumentsTab extends StatelessWidget {
  final Map<String, dynamic> riderData;
  final Function(String key, String label) onReject;

  const _DocumentsTab({required this.riderData, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final rawDocs = (riderData['documents'] as Map<String, dynamic>?) ?? {};
    final docs = rawDocs.map((k, v) => MapEntry(k.toString(), v));

    final uploadedCards = <Widget>[];
    for (final section in RiderDocumentRequirements.sections) {
      final (sectionTitle, items) = section;
      final sectionCards = <Widget>[];

      for (final item in items) {
        final (label, key) = item;
        final docData = RiderDocumentRequirements.findDocumentData(docs, key);
        final url = RiderDocumentRequirements.resolveUrl(docData);
        if (url.isEmpty) continue;

        final status = RiderDocumentRequirements.resolveStatus(
          docData,
          url: url,
        );
        String? reason;
        if (docData is Map) {
          reason = docData['rejectionReason']?.toString();
        }

        sectionCards.add(
          _DocCard(
            label: label,
            url: url,
            docKey: key,
            status: status,
            rejectionReason: reason,
            onReject: () => onReject(key, label),
          ),
        );
      }

      if (sectionCards.isEmpty) continue;

      uploadedCards.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                sectionTitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sectionCards,
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // Also show any uploaded docs not in the canonical list (legacy/extra).
    final knownKeys = RiderDocumentRequirements.sections
        .expand((section) => section.$2.map((item) => item.$2))
        .toSet();
    final extraCards = <Widget>[];
    for (final entry in docs.entries) {
      final canonical = RiderDocumentRequirements.legacyKeyAliases[entry.key] ??
          entry.key;
      if (knownKeys.contains(canonical)) continue;

      final url = RiderDocumentRequirements.resolveUrl(entry.value);
      if (url.isEmpty) continue;

      extraCards.add(
        _DocCard(
          label: entry.key,
          url: url,
          docKey: entry.key,
          status: RiderDocumentRequirements.resolveStatus(
            entry.value,
            url: url,
          ),
          onReject: () => onReject(entry.key, entry.key),
        ),
      );
    }

    if (uploadedCards.isEmpty && extraCards.isEmpty) {
      return const EmptyState(
        message: 'No uploaded documents yet',
        icon: Icons.folder_open_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...uploadedCards,
          if (extraCards.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Other Documents',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: extraCards,
            ),
          ],
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String label;
  final String url;
  final String docKey;
  final String status;
  final String? rejectionReason;
  final VoidCallback onReject;

  const _DocCard({
    required this.label,
    required this.url,
    required this.docKey,
    required this.status,
    this.rejectionReason,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        border: Border.all(
          color: status == 'rejected'
              ? AdminTheme.accent
              : status == 'approved'
              ? AdminTheme.statusActive
              : AdminTheme.divider,
          width: status == 'rejected' || status == 'approved' ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            child: GestureDetector(
              onTap: () => _showFullImage(context, url),
              child: CachedNetworkImage(
                imageUrl: url,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 120,
                  color: AdminTheme.surface,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 120,
                  color: AdminTheme.surface,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(status),
                if (rejectionReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    rejectionReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AdminTheme.accent,
                    ),
                  ),
                ],
                if (status != 'rejected') ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminTheme.accent,
                        side: const BorderSide(color: AdminTheme.accent),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      onPressed: onReject,
                      child: Text(
                        'Reject',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Open in browser',
                    onPressed: () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_outlined),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in Browser'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delivery History Tab ─────────────────────────────────────────────────────
class _DeliveryHistoryTab extends StatelessWidget {
  final String riderId;
  const _DeliveryHistoryTab({required this.riderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamRiderBookings(riderId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No deliveries',
            icon: Icons.local_shipping_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = AdminRepository.normalizeBookingData(
              docs[i].id,
              docs[i].data() as Map<String, dynamic>,
            );
            final status = d['status'] ?? 'unknown';
            final fare = (d['finalFare'] ?? d['estimatedFare'] ?? 0).toString();
            return ListTile(
              dense: true,
              leading: StatusBadge(status),
              title: Text(
                '${d['pickupAddress'] ?? 'Pickup'} → ${d['dropoffAddress'] ?? 'Dropoff'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12),
              ),
              trailing: Text(
                '₱ $fare',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => context.go('/bookings/${docs[i].id}'),
            );
          },
        );
      },
    );
  }
}

// ─── Earnings Tab ─────────────────────────────────────────────────────────────
class _EarningsTab extends StatelessWidget {
  final String riderId;
  const _EarningsTab({required this.riderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AdminConstants.colWalletTransactions)
          .where('riderId', isEqualTo: riderId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            message: 'No earnings records',
            icon: Icons.payments_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminTheme.divider),
          itemBuilder: (context, i) {
            final d = AdminRepository.normalizeWalletTransactionData(
              docs[i].id,
              docs[i].data() as Map<String, dynamic>,
            );
            final amount = (d['amount'] as num).toDouble();
            final type = (d['type'] ?? d['transactionType'] ?? '').toString();
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.payments_outlined,
                color: amount >= 0
                    ? AdminTheme.statusActive
                    : AdminTheme.accent,
              ),
              title: Text(
                type.replaceAll('_', ' '),
                style: GoogleFonts.inter(fontSize: 12),
              ),
              trailing: Text(
                '₱ ${amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: amount >= 0
                      ? AdminTheme.statusActive
                      : AdminTheme.accent,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
