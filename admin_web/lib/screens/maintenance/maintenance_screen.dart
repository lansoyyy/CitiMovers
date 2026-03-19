import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../widgets/common_widgets.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _loading = true;
  String? _runningTask;
  Map<String, int> _summary = const {'users': 0, 'riders': 0, 'bookings': 0};

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    final summary = await AdminRepository.getBackfillSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _runBackfill(String taskKey) async {
    setState(() => _runningTask = taskKey);

    int updated = 0;
    if (taskKey == 'users') {
      updated = await AdminRepository.runUsersBackfill();
    } else if (taskKey == 'riders') {
      updated = await AdminRepository.runRidersBackfill();
    } else if (taskKey == 'bookings') {
      updated = await AdminRepository.runBookingsBackfill();
    }

    await _loadSummary();
    if (!mounted) return;
    setState(() => _runningTask = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated $updated $taskKey documents.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Maintenance & Backfills',
            trailing: OutlinedButton.icon(
              onPressed: _loading ? null : _loadSummary,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Scan'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AdminTheme.statusPending,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These tools write directly to production Firestore. Use them only after reviewing the scan counts and only for schema-normalization work.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _BackfillCard(
                    title: 'Users',
                    description:
                        'Backfill missing isSuspended, accountStatus, and walletBalance defaults.',
                    count: _summary['users'] ?? 0,
                    running: _runningTask == 'users',
                    onRun: () => _runBackfill('users'),
                  ),
                  _BackfillCard(
                    title: 'Riders',
                    description:
                        'Backfill missing account flags and normalize document review metadata.',
                    count: _summary['riders'] ?? 0,
                    running: _runningTask == 'riders',
                    onRun: () => _runBackfill('riders'),
                  ),
                  _BackfillCard(
                    title: 'Bookings',
                    description:
                        'Backfill issue metadata, reconciliation flags, and canonical booking IDs.',
                    count: _summary['bookings'] ?? 0,
                    running: _runningTask == 'bookings',
                    onRun: () => _runBackfill('bookings'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BackfillCard extends StatelessWidget {
  final String title;
  final String description;
  final int count;
  final bool running;
  final VoidCallback onRun;

  const _BackfillCard({
    required this.title,
    required this.description,
    required this.count,
    required this.running,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count documents need updates',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: count > 0
                    ? AdminTheme.statusPending
                    : AdminTheme.statusActive,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: running || count == 0 ? null : onRun,
                icon: running
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(running ? 'Running...' : 'Run Backfill'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
