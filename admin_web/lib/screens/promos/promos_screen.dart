import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/common_widgets.dart';

class PromosScreen extends StatefulWidget {
  const PromosScreen({super.key});

  @override
  State<PromosScreen> createState() => _PromosScreenState();
}

class _PromosScreenState extends State<PromosScreen> {
  Future<void> _showBannerDialog({
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final subtitleCtrl = TextEditingController(
      text: existing?['subtitle'] ?? '',
    );
    final imageUrlCtrl = TextEditingController(
      text: existing?['imageUrl'] ?? '',
    );
    bool isActive = existing?['isActive'] ?? true;

    final saved =
        await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setSt) {
              return AlertDialog(
                title: Text(
                  docId == null ? 'Create Promo Banner' : 'Edit Banner',
                ),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subtitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle / body text',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        activeColor: AdminTheme.primary,
                        onChanged: (v) => setSt(() => isActive = v),
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
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!saved) return;

    final data = {
      'title': titleCtrl.text.trim(),
      'subtitle': subtitleCtrl.text.trim(),
      'imageUrl': imageUrlCtrl.text.trim(),
      'isActive': isActive,
    };

    await AdminRepository.upsertBanner(docId, data);
  }

  Future<void> _deleteBanner(String docId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Banner',
      message: 'Remove this promo banner? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await AdminRepository.deleteBanner(docId);
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
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showBannerDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Banner'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AdminRepository.streamPromoBanners(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const EmptyState(
                    message: 'No promo banners yet',
                    icon: Icons.campaign_outlined,
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final isActive = d['isActive'] == true;
                    final ts = AdminRepository.parseTimestamp(
                      d['createdAt'] ?? d['updatedAt'],
                    );

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d['title'] ?? '—',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AdminTheme.statusActive.withOpacity(
                                            0.1,
                                          )
                                        : AdminTheme.textSecondary.withOpacity(
                                            0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? AdminTheme.statusActive
                                          : AdminTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d['subtitle'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AdminTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            if (ts != null)
                              Text(
                                DateFormat('MMM d, yyyy').format(ts),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _showBannerDialog(
                                    docId: doc.id,
                                    existing: d,
                                  ),
                                  child: const Text('Edit'),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AdminTheme.accent,
                                  ),
                                  onPressed: () => _deleteBanner(doc.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
