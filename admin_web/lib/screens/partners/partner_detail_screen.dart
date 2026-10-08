import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../services/csv_export_service.dart';
import '../../services/partner_repository.dart';
import '../../utils/contact_parsing.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/common_widgets.dart';

class PartnerDetailScreen extends StatefulWidget {
  final String partnerId;
  const PartnerDetailScreen({super.key, required this.partnerId});

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  static const _liveStatuses = {
    'accepted',
    'arrived_at_pickup',
    'loading',
    'loading_complete',
    'in_transit',
    'arrived_at_dropoff',
    'unloading',
    'unloading_complete',
    'damage_reported',
    'receiving',
  };

  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _partner;
  bool _saving = false;
  bool _togglingStatus = false;
  String _tripFilter = 'all';

  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _reportEmailEnabled = false;
  final List<TextEditingController> _emailCtrls = [];

  bool _reportSmsEnabled = false;
  final List<TextEditingController> _phoneCtrls = [];

  /// Latest trips snapshot, kept for the CSV export button.
  List<Map<String, dynamic>> _latestTrips = const [];

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    for (final controller in _emailCtrls) {
      controller.dispose();
    }
    for (final controller in _phoneCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPartner() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final partner =
          await AdminPartnerRepository.getNormalizedPartner(widget.partnerId);
      if (!mounted) return;
      if (partner == null) {
        setState(() {
          _loading = false;
          _loadError = 'Partner not found.';
        });
        return;
      }
      _hydrate(partner);
      setState(() {
        _partner = partner;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _hydrate(Map<String, dynamic> partner) {
    _nameCtrl.text = (partner['name'] ?? '').toString();
    _contactCtrl.text = (partner['contactPerson'] ?? '').toString();
    _phoneCtrl.text = (partner['phone'] ?? '').toString();
    _emailCtrl.text = (partner['email'] ?? '').toString();
    _addressCtrl.text = (partner['address'] ?? '').toString();
    _notesCtrl.text = (partner['notes'] ?? '').toString();

    _reportEmailEnabled = partner['reportEmailEnabled'] == true;
    final emails = (partner['reportEmails'] as List?) ?? const [];
    for (final controller in _emailCtrls) {
      controller.dispose();
    }
    _emailCtrls.clear();
    if (emails.isEmpty) {
      _emailCtrls.add(TextEditingController());
    } else {
      for (final email in emails) {
        _emailCtrls.add(TextEditingController(text: email.toString()));
      }
    }

    _reportSmsEnabled = partner['reportSmsEnabled'] == true;
    final phones = (partner['reportPhones'] as List?) ?? const [];
    for (final controller in _phoneCtrls) {
      controller.dispose();
    }
    _phoneCtrls.clear();
    if (phones.isEmpty) {
      _phoneCtrls.add(TextEditingController());
    } else {
      for (final phone in phones) {
        _phoneCtrls.add(TextEditingController(text: phone.toString()));
      }
    }
  }

  Future<void> _savePartner() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner name is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final emails = ContactParsing.parseEmailRecipients(
      _emailCtrls.map((controller) => controller.text).toList(),
    );
    if (_reportEmailEnabled && emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one valid email recipient or untick Email reports.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final phones = ContactParsing.parsePhoneNumbers(
      _phoneCtrls.map((controller) => controller.text).toList(),
    );

    setState(() => _saving = true);
    try {
      await AdminPartnerRepository.savePartner(
        partnerId: widget.partnerId,
        name: name,
        contactPerson: _contactCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        address: _addressCtrl.text,
        notes: _notesCtrl.text,
        reportEmailEnabled: _reportEmailEnabled,
        reportEmails: emails,
        reportSmsEnabled: _reportSmsEnabled,
        reportPhones: phones,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner updated.')),
      );
      await _loadPartner();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleStatus() async {
    if (_togglingStatus) return;
    final isActive =
        (_partner?['status'] ?? AdminPartnerRepository.statusActive) ==
            AdminPartnerRepository.statusActive;
    final nextStatus = isActive
        ? AdminPartnerRepository.statusInactive
        : AdminPartnerRepository.statusActive;

    final confirmed = await ConfirmDialog.show(
      context,
      title: isActive ? 'Deactivate Partner' : 'Activate Partner',
      message: isActive
          ? 'Inactive partners receive no delivery reports and their units '
              'stop being linked to new trips. Continue?'
          : 'Activate this partner so their units route delivery reports '
              'again?',
      confirmLabel: isActive ? 'Deactivate' : 'Activate',
      confirmColor:
          isActive ? AdminTheme.statusPending : AdminTheme.statusActive,
    );
    if (!confirmed) return;

    setState(() => _togglingStatus = true);
    try {
      await AdminPartnerRepository.setPartnerStatus(
        partnerId: widget.partnerId,
        status: nextStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partner ${isActive ? 'deactivated' : 'activated'}.')),
      );
      await _loadPartner();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingStatus = false);
      }
    }
  }

  // ─── declared units ───────────────────────────────────────────────────────

  Future<void> _addUnit() async {
    final selectedRiderId = await showDialog<String>(
      context: context,
      builder: (_) => _AddUnitDialog(partnerId: widget.partnerId),
    );
    if (!mounted || selectedRiderId == null) return;
    try {
      await AdminPartnerRepository.assignRiderToPartner(
        riderId: selectedRiderId,
        partnerId: widget.partnerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit assigned to this partner.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeUnit(Map<String, dynamic> unit) async {
    final name = (unit['name'] ?? 'this unit').toString();
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove Unit',
      message: 'Remove $name from this partner? Future trips by this unit '
          'will no longer report to the partner.',
      confirmLabel: 'Remove',
      confirmColor: AdminTheme.accent,
    );
    if (!confirmed) return;

    try {
      await AdminPartnerRepository.removeRiderFromPartner(
        riderId: (unit['id'] ?? '').toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name removed from partner.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── trips ────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterTrips(List<Map<String, dynamic>> trips) {
    switch (_tripFilter) {
      case 'live':
        return trips
            .where((trip) =>
                _liveStatuses.contains((trip['status'] ?? '').toString()))
            .toList();
      case 'completed':
        return trips
            .where((trip) => trip['status'] == 'completed')
            .toList();
      default:
        return trips;
    }
  }

  void _exportTrips(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trips to export.')),
      );
      return;
    }

    final rows = trips.map((trip) {
      final created = AdminRepository.parseTimestamp(trip['createdAt']);
      final fare = (trip['grossAmount'] ?? trip['finalFare'] ?? 0) as num;
      return [
        created != null
            ? DateFormat('MMM d, yyyy h:mm a').format(created)
            : '',
        (trip['tripNumber'] ?? '').toString(),
        (trip['id'] ?? '').toString(),
        (trip['riderName'] ?? '').toString(),
        (trip['pickupAddress'] ?? '').toString(),
        (trip['dropoffAddress'] ?? '').toString(),
        (trip['status'] ?? '').toString(),
        fare.toStringAsFixed(2),
      ];
    }).toList();

    AdminCsvExportService.downloadCsv(
      fileName:
          'partner_trips_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      headers: const [
        'Date',
        'Trip No',
        'Booking ID',
        'Unit / Driver',
        'Pickup',
        'Dropoff',
        'Status',
        'Fare (info)',
      ],
      rows: rows,
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_partner == null && _loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadPartner, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_partner == null) {
      return const Center(child: Text('Partner not found.'));
    }

    final partner = _partner!;
    final isActive =
        (partner['status'] ?? AdminPartnerRepository.statusActive) ==
            AdminPartnerRepository.statusActive;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/partners'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Partners'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (partner['name'] ?? 'Partner').toString(),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    StatusBadge(partner['status'] ?? 'active'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _togglingStatus ? null : _toggleStatus,
                icon: Icon(
                  isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 16,
                ),
                label: Text(isActive ? 'Deactivate' : 'Activate'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : _savePartner,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save Changes'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildReportChannelsCard(),
                  const SizedBox(height: 16),
                  _buildUnitsCard(),
                  const SizedBox(height: 16),
                  _buildTripsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Partner Profile'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 700;
                final width =
                    twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Partner / company name *',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _contactCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contact person',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportChannelsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Report Delivery'),
            const SizedBox(height: 4),
            Text(
              'Delivery completion reports for every trip handled by this '
              'partner\'s units are sent automatically to the enabled channels.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // ── Email channel ──
            CheckboxListTile(
              value: _reportEmailEnabled,
              onChanged: (value) =>
                  setState(() => _reportEmailEnabled = value == true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                'Email reports',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Send completion reports to these recipients',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
              ),
            ),
            if (_reportEmailEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(_emailCtrls.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _emailCtrls[index],
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText:
                                      'Email recipient ${index + 1}',
                                  hintText: 'e.g., pod@company.com',
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_emailCtrls.length > 1) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Remove recipient',
                                onPressed: () => setState(() {
                                  _emailCtrls.removeAt(index).dispose();
                                }),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _emailCtrls.add(TextEditingController()),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add another email recipient'),
                    ),
                    Text(
                      'Tip: you can paste several addresses separated with a '
                      'comma — they are saved as separate recipients.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: AdminTheme.divider),
            // ── Phone channel ──
            CheckboxListTile(
              value: _reportSmsEnabled,
              onChanged: (value) =>
                  setState(() => _reportSmsEnabled = value == true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                'Phone reports',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Save cellphone numbers per partner (SMS sending will be '
                'enabled in a future update)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
              ),
            ),
            if (_reportSmsEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(_phoneCtrls.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrls[index],
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText:
                                      'Cellphone number ${index + 1}',
                                  hintText: 'e.g., 09171234567',
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_phoneCtrls.length > 1) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Remove number',
                                onPressed: () => setState(() {
                                  _phoneCtrls.removeAt(index).dispose();
                                }),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _phoneCtrls.add(TextEditingController()),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add another cellphone number'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Declared Units',
              trailing: OutlinedButton.icon(
                onPressed: _addUnit,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Unit'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Trips handled by these registered units automatically report '
              'to this partner.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: AdminPartnerRepository.streamUnitsForPartner(
                widget.partnerId,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final units = snap.data ?? const [];
                if (units.isEmpty) {
                  return const EmptyState(
                    message: 'No units declared yet',
                    icon: Icons.local_shipping_outlined,
                  );
                }
                return Column(
                  children: units.map((unit) {
                    final name = (unit['name'] ?? 'Unknown Rider').toString();
                    final plate = (unit['plateNumber'] ?? '').toString();
                    final vehicle =
                        (unit['vehicleType'] ?? unit['truckType'] ?? '')
                            .toString();
                    final status =
                        (unit['accountStatus'] ?? 'active').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            AdminTheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.inter(
                            color: AdminTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (plate.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AdminTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plate.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AdminTheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        [
                          if (vehicle.isNotEmpty) vehicle,
                          status,
                        ].join(' • '),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove from partner',
                        onPressed: () => _removeUnit(unit),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 18,
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Partner Trips',
              trailing: OutlinedButton.icon(
                onPressed: () => _exportTrips(_filterTrips(_latestTrips)),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export CSV'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ('All', 'all'),
                ('Live', 'live'),
                ('Completed', 'completed'),
              ].map((option) {
                final (label, value) = option;
                final selected = _tripFilter == value;
                return FilterChip(
                  label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
                  selected: selected,
                  selectedColor: AdminTheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: AdminTheme.primary,
                  onSelected: (_) => setState(() => _tripFilter = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: AdminPartnerRepository.streamPartnerTrips(
                widget.partnerId,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Unable to load trips. ${snap.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
                final trips = _filterTrips(snap.data ?? const []);
                _latestTrips = snap.data ?? const [];
                if (trips.isEmpty) {
                  return const EmptyState(
                    message: 'No trips for this partner yet',
                    icon: Icons.receipt_long_outlined,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final trip in trips) _buildTripTile(trip),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final created = AdminRepository.parseTimestamp(trip['createdAt']);
    final fare = (trip['grossAmount'] ?? trip['finalFare'] ?? 0) as num;
    final tripLabel = (trip['tripNumber'] ?? '').toString().isNotEmpty
        ? trip['tripNumber'].toString()
        : (trip['id'] ?? '').toString();
    final shortId = tripLabel.length > 8
        ? tripLabel.substring(0, 8).toUpperCase()
        : tripLabel.toUpperCase();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => context.go('/bookings/${trip['id']}'),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${trip['pickupAddress'] ?? '—'}  →  ${trip['dropoffAddress'] ?? '—'}',
              style: GoogleFonts.inter(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(trip['status'] ?? 'unknown'),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          [
            '#$shortId',
            if (created != null) DateFormat('MMM d, h:mm a').format(created),
            (trip['riderName'] ?? '').toString(),
            '₱ ${fare.toStringAsFixed(2)} (info)',
          ].join(' • '),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AdminTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Add Unit dialog ────────────────────────────────────────────────────────

class _AddUnitDialog extends StatefulWidget {
  final String partnerId;
  const _AddUnitDialog({required this.partnerId});

  @override
  State<_AddUnitDialog> createState() => _AddUnitDialogState();
}

class _AddUnitDialogState extends State<_AddUnitDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.of(context).size.width;
    final dialogWidth = viewportWidth > 820 ? 640.0 : viewportWidth * 0.82;

    return AlertDialog(
      title: const Text('Add Unit to Partner'),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a registered unit. Units already carrying another '
              'partner are flagged before reassignment.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search units',
                hintText: 'Name or plate number',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: StreamBuilder<QuerySnapshot>(
                stream: AdminRepository.streamRiders(statusFilter: 'active'),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final query = _query.trim().toLowerCase();
                  final riders = (snap.data?.docs ?? []).map((doc) {
                    return AdminRepository.normalizeRiderData(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                  }).where((rider) {
                    if (query.isEmpty) return true;
                    final haystack = [
                      rider['name'],
                      rider['plateNumber'],
                      rider['vehicleType'],
                    ]
                        .map((value) => (value ?? '').toString().toLowerCase())
                        .join(' ');
                    return haystack.contains(query);
                  }).toList();

                  if (riders.isEmpty) {
                    return const EmptyState(
                      message: 'No matching active units',
                      icon: Icons.local_shipping_outlined,
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: riders.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminTheme.divider),
                    itemBuilder: (context, index) {
                      final rider = riders[index];
                      final riderId = (rider['id'] ?? '').toString();
                      final currentPartnerId =
                          (rider['partnerId'] ?? '').toString().trim();
                      final currentPartnerName =
                          (rider['partnerName'] ?? '').toString().trim();
                      final isSamePartner =
                          currentPartnerId == widget.partnerId;
                      final hasOtherPartner = currentPartnerId.isNotEmpty &&
                          currentPartnerId != widget.partnerId;

                      return ListTile(
                        dense: true,
                        enabled: !isSamePartner,
                        onTap: isSamePartner
                            ? null
                            : () async {
                                if (hasOtherPartner) {
                                  final confirmed =
                                      await ConfirmDialog.show(
                                    context,
                                    title: 'Reassign Unit?',
                                    message:
                                        'This unit currently belongs to '
                                        '"$currentPartnerName". Reassign it '
                                        'to this partner?',
                                    confirmLabel: 'Reassign',
                                    confirmColor: AdminTheme.statusPending,
                                  );
                                  if (!confirmed) return;
                                }
                                if (context.mounted) {
                                  Navigator.pop(context, riderId);
                                }
                              },
                        title: Text(
                          (rider['name'] ?? 'Unknown Rider').toString(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            (rider['plateNumber'] ?? '').toString(),
                            (rider['vehicleType'] ?? '').toString(),
                            if (isSamePartner)
                              'Already in this partner'
                            else if (hasOtherPartner)
                              'Partner: $currentPartnerName',
                          ].where((part) => part.isNotEmpty).join(' • '),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: hasOtherPartner
                                ? AdminTheme.statusPending
                                : AdminTheme.textSecondary,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
