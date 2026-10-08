import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/report_settings_repository.dart';
import '../../utils/contact_parsing.dart';
import '../../widgets/common_widgets.dart';

/// Edits `app_config/report_settings` — the recipient list the
/// `sendCompletionReport` Cloud Function reads when sending delivery
/// completion reports. No rider app update is needed after changes here.
class ReportSettingsScreen extends StatefulWidget {
  const ReportSettingsScreen({super.key});

  @override
  State<ReportSettingsScreen> createState() => _ReportSettingsScreenState();
}

class _ReportSettingsScreenState extends State<ReportSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  String _updatedBy = '';
  DateTime? _updatedAt;
  final List<TextEditingController> _recipientCtrls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _recipientCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await ReportSettingsRepository.getReportSettings();
      if (!mounted) return;
      _hydrate(settings);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report settings: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _hydrate(Map<String, dynamic> settings) {
    _enabled = settings['enabled'] != false;
    _updatedBy = (settings['updatedBy'] ?? '').toString();
    _updatedAt = settings['updatedAt'] as DateTime?;

    final recipients = (settings['recipients'] as List?) ?? const [];
    for (final controller in _recipientCtrls) {
      controller.dispose();
    }
    _recipientCtrls.clear();
    if (recipients.isEmpty) {
      _recipientCtrls.add(TextEditingController());
    } else {
      for (final recipient in recipients) {
        _recipientCtrls.add(TextEditingController(text: recipient.toString()));
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final recipients = ContactParsing.parseEmailRecipients(
      _recipientCtrls.map((controller) => controller.text).toList(),
    );

    setState(() => _saving = true);
    try {
      await ReportSettingsRepository.saveReportSettings(
        enabled: _enabled,
        recipients: recipients,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report settings saved.')),
      );
      await _load();
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Report Settings',
            trailing: ElevatedButton.icon(
              onPressed: _loading || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Settings'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Delivery completion reports are sent by the Cloud Function the '
            'moment a trip is completed — changing the recipients here takes '
            'effect immediately without updating the rider app.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AdminTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value == true),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              'Send delivery completion emails',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _enabled
                                  ? 'Reports are emailed when a booking is completed.'
                                  : 'All completion report emails are OFF, including the customer copy.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _enabled
                                    ? AdminTheme.textSecondary
                                    : AdminTheme.accent,
                              ),
                            ),
                          ),
                          const Divider(color: AdminTheme.divider),
                          const SizedBox(height: 8),
                          Text(
                            'Business recipients',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Every completed trip report is sent to these '
                            'addresses. Customer, driver, partner, and '
                            'per-booking recipients are always included '
                            'automatically.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_recipientCtrls.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _recipientCtrls[index],
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Recipient email ${index + 1}',
                                        hintText: 'e.g., excel_gesite@yahoo.com',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_recipientCtrls.length > 1) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Remove recipient',
                                      onPressed: () => setState(() {
                                        _recipientCtrls
                                            .removeAt(index)
                                            .dispose();
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
                              () => _recipientCtrls
                                  .add(TextEditingController()),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add another email recipient'),
                          ),
                          Text(
                            'Tip: you can paste several addresses separated '
                            'with a comma — they are saved as separate '
                            'recipients. If all rows are empty, the list '
                            'falls back to ${ReportSettingsRepository.defaultRecipients.join(', ')}.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How this works',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• The Cloud Function "sendCompletionReport" '
                            'watches bookings and sends the report when a '
                            'trip becomes completed.\n'
                            '• It waits ~2 minutes after completion so the '
                            'rider app can finish uploading photos before '
                            'the email is built.\n'
                            '• Recipients here pick up changes instantly — '
                            'no app update needed.\n'
                            '• Delivery status is recorded on each booking '
                            '(completionReportStatus / completionReportSentAt).',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminTheme.textSecondary,
                              height: 1.6,
                            ),
                          ),
                          if (_updatedAt != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Last updated'
                              '${_updatedBy.isNotEmpty ? ' by $_updatedBy' : ''}'
                              ' on ${DateFormat('MMM d, yyyy h:mm a').format(_updatedAt!)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AdminTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
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
