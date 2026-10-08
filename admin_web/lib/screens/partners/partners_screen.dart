import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../services/partner_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = '';
  bool _creating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> partners) {
    var result = partners;
    if (_statusFilter.isNotEmpty) {
      result = result
          .where((partner) =>
              (partner['status'] ?? AdminPartnerRepository.statusActive) ==
              _statusFilter)
          .toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((partner) {
        final haystack = [
          partner['name'],
          partner['contactPerson'],
          partner['phone'],
          partner['email'],
        ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
        return haystack.contains(q);
      }).toList();
    }
    return result;
  }

  Future<void> _createPartner() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final createdName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? formError;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Add Partner'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register a subcontractor partner. After saving, declare '
                    'their units and configure email reports on the partner '
                    'page.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Partner / company name (required)',
                      errorText: formError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contact person',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setDialogState(
                      () => formError = 'Partner name is required.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, nameCtrl.text.trim());
                },
                child: const Text('Add Partner'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || createdName == null) {
      nameCtrl.dispose();
      contactCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      return;
    }

    setState(() => _creating = true);
    try {
      final partnerId = await AdminPartnerRepository.createPartner(
        name: createdName,
        contactPerson: contactCtrl.text,
        phone: phoneCtrl.text,
        email: emailCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partner "$createdName" created.')),
      );
      context.go('/partners/$partnerId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      nameCtrl.dispose();
      contactCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Subcontractor Partners',
            trailing: ElevatedButton.icon(
              onPressed: _creating ? null : _createPartner,
              icon: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Add Partner'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Partner units automatically send delivery completion email '
            'reports to their configured recipients.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AdminTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SearchField(
                controller: _searchCtrl,
                hint: 'Search by name, contact, phone',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  ('All', ''),
                  ('Active', AdminPartnerRepository.statusActive),
                  ('Inactive', AdminPartnerRepository.statusInactive),
                ].map((option) {
                  final (label, value) = option;
                  final selected = _statusFilter == value;
                  return FilterChip(
                    label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
                    selected: selected,
                    selectedColor: AdminTheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: AdminTheme.primary,
                    onSelected: (_) => setState(() => _statusFilter = value),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: AdminPartnerRepository.streamPartners(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return EmptyState(
                    message: 'Unable to load partners: ${snap.error}',
                    icon: Icons.error_outline,
                  );
                }

                final partners = _filter(snap.data ?? const []);
                if (partners.isEmpty) {
                  return const EmptyState(
                    message: 'No partners yet. Add your first partner.',
                    icon: Icons.handshake_outlined,
                  );
                }

                return Card(
                  child: ListView.separated(
                    itemCount: partners.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminTheme.divider),
                    itemBuilder: (context, index) {
                      final partner = partners[index];
                      final name = (partner['name'] ?? 'Unnamed Partner')
                          .toString();
                      final contactPerson =
                          (partner['contactPerson'] ?? '').toString();
                      final phone = (partner['phone'] ?? '').toString();
                      final email = (partner['email'] ?? '').toString();
                      final status =
                          (partner['status'] ??
                                  AdminPartnerRepository.statusActive)
                              .toString();
                      final isActive =
                          status == AdminPartnerRepository.statusActive;
                      final reportEmails =
                          (partner['reportEmails'] as List?) ?? const [];
                      final reportPhones =
                          (partner['reportPhones'] as List?) ?? const [];
                      final emailEnabled =
                          partner['reportEmailEnabled'] == true;
                      final smsEnabled = partner['reportSmsEnabled'] == true;

                      final subtitleParts = [
                        if (contactPerson.isNotEmpty) contactPerson,
                        if (phone.isNotEmpty) phone,
                        if (email.isNotEmpty) email,
                      ];

                      return ListTile(
                        onTap: () => context.go('/partners/${partner['id']}'),
                        leading: CircleAvatar(
                          backgroundColor:
                              AdminTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.handshake_outlined,
                            color: AdminTheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!isActive) ...[
                              const SizedBox(width: 8),
                              const StatusBadge('inactive'),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (subtitleParts.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    subtitleParts.join(' • '),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AdminTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                const Spacer(),
                              if (emailEnabled) ...[
                                const SizedBox(width: 8),
                                _ChannelChip(
                                  icon: Icons.email_outlined,
                                  label: reportEmails.isEmpty
                                      ? 'Email'
                                      : 'Email (${reportEmails.length})',
                                ),
                              ],
                              if (smsEnabled) ...[
                                const SizedBox(width: 8),
                                _ChannelChip(
                                  icon: Icons.phone_android_outlined,
                                  label: reportPhones.isEmpty
                                      ? 'Phone'
                                      : 'Phone (${reportPhones.length})',
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AdminTheme.textSecondary,
                        ),
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

class _ChannelChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ChannelChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AdminTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
