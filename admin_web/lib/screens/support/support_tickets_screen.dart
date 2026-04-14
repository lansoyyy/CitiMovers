import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

// ─── Role helpers ─────────────────────────────────────────────────────────────
String _roleName(String role) {
  switch (role) {
    case 'coordinator':
      return 'Coordinator';
    case 'manager':
      return 'Manager';
    case 'president':
      return 'President/CEO';
    default:
      return 'Admin';
  }
}

bool _canActOnManagerQueue(String role) =>
    role == 'manager' || role == 'admin' || role == 'president';

bool _canActOnPresidential(String role) =>
    role == 'admin' || role == 'president';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  late final List<(String label, List<String>? statuses)> _tabs;
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _selectedTicketId;
  bool _showDetail = false;

  // New-ticket-for-caller form
  final _callerNameCtrl = TextEditingController();
  final _callerSubjectCtrl = TextEditingController();
  final _callerDescCtrl = TextEditingController();
  final _callerTripCtrl = TextEditingController();
  String _callerCategory = 'app';
  bool _creatingTicket = false;

  static List<(String, List<String>?)> _buildTabsForRole(String role) {
    if (role == 'coordinator') {
      return [
        ('All', null),
        ('Pending', ['open', 'pending']),
        ('Resolved', ['resolved']),
      ];
    } else if (role == 'manager') {
      return [
        ('All', null),
        ('Pending', ['open', 'pending']),
        ('Manager Queue', ['escalated_manager']),
        ('Resolved', ['resolved']),
      ];
    } else {
      return [
        ('All', null),
        ('Pending', ['open', 'pending']),
        ('Manager Queue', ['escalated_manager']),
        ('Presidential', ['escalated_presidential']),
        ('Resolved', ['resolved']),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabsForRole(AdminAuthService().currentRole);
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _callerNameCtrl.dispose();
    _callerSubjectCtrl.dispose();
    _callerDescCtrl.dispose();
    _callerTripCtrl.dispose();
    super.dispose();
  }

  List<String>? get _currentStatuses => _tabs[_tabController.index].$2;

  void _openDetail(String ticketId) => setState(() {
    _selectedTicketId = ticketId;
    _showDetail = true;
  });

  void _closeDetail() => setState(() {
    _showDetail = false;
    _selectedTicketId = null;
  });

  Future<void> _showNewTicketDialog() async {
    _callerNameCtrl.clear();
    _callerSubjectCtrl.clear();
    _callerDescCtrl.clear();
    _callerTripCtrl.clear();
    setState(() => _callerCategory = 'app');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text(
              'New Ticket — on behalf of caller',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _callerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Caller Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _callerSubjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _callerTripCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Trip # (optional)',
                        hintText: 'e.g. 2026-12-04-00001',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _callerCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'app',
                          child: Text('App Issue'),
                        ),
                        DropdownMenuItem(
                          value: 'logistics',
                          child: Text('Logistics Concern'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDlgState(() => _callerCategory = v ?? 'app'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _callerDescCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _creatingTicket
                    ? null
                    : () async {
                        if (_callerNameCtrl.text.trim().isEmpty ||
                            _callerSubjectCtrl.text.trim().isEmpty ||
                            _callerDescCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all required fields.'),
                            ),
                          );
                          return;
                        }
                        setDlgState(() => _creatingTicket = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final id = await AdminRepository.createTicketForCaller(
                          callerName: _callerNameCtrl.text.trim(),
                          subject: _callerSubjectCtrl.text.trim(),
                          description: _callerDescCtrl.text.trim(),
                          category: _callerCategory,
                          tripNumber: _callerTripCtrl.text.trim().isEmpty
                              ? null
                              : _callerTripCtrl.text.trim(),
                        );
                        setDlgState(() => _creatingTicket = false);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (id != null) {
                          _openDetail(id);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Ticket created.')),
                          );
                        }
                      },
                child: _creatingTicket
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Ticket'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AdminAuthService().currentRole;
    return Scaffold(
      backgroundColor: AdminTheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                SectionHeader(title: 'Support Tickets'),
                const Spacer(),
                SearchField(
                  controller: _searchCtrl,
                  hint: 'Search ticket # or subject...',
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _showNewTicketDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Ticket'),
                ),
              ],
            ),
          ),

          // ── Tabs ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              onTap: (_) => setState(() {}),
              tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
            ),
          ),

          const Divider(height: 1),

          // ── Body: list + detail pane ──────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: ticket list
                SizedBox(
                  width: _showDetail ? 380 : double.infinity,
                  child: _TicketList(
                    statuses: _currentStatuses,
                    search: _search,
                    selectedId: _selectedTicketId,
                    onSelect: _openDetail,
                  ),
                ),

                // Right: detail pane
                if (_showDetail && _selectedTicketId != null)
                  Expanded(
                    child: _TicketDetailPane(
                      ticketId: _selectedTicketId!,
                      role: role,
                      onClose: _closeDetail,
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

// ─────────────────────────────────────────────────────────────────────────────
// Ticket List
// ─────────────────────────────────────────────────────────────────────────────

class _TicketList extends StatelessWidget {
  final List<String>? statuses;
  final String search;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _TicketList({
    required this.statuses,
    required this.search,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminRepository.streamSupportTickets(statuses: statuses),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((d) {
          if (search.isEmpty) return true;
          final data = d.data() as Map<String, dynamic>;
          final num = (data['ticketNumber'] ?? '').toString().toLowerCase();
          final sub = (data['subject'] ?? '').toString().toLowerCase();
          final name = (data['submittedByName'] ?? '').toString().toLowerCase();
          final trip = (data['tripNumber'] ?? '').toString().toLowerCase();
          return num.contains(search) ||
              sub.contains(search) ||
              name.contains(search) ||
              trip.contains(search);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No tickets found.',
              style: GoogleFonts.inter(color: AdminTheme.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final doc = filtered[i];
            final data = doc.data() as Map<String, dynamic>;
            return _TicketRow(
              docId: doc.id,
              data: data,
              isSelected: doc.id == selectedId,
              onTap: () => onSelect(doc.id),
            );
          },
        );
      },
    );
  }
}

class _TicketRow extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isSelected;
  final VoidCallback onTap;

  const _TicketRow({
    required this.docId,
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ticketNumber = (data['ticketNumber'] ?? '').toString();
    final subject = (data['subject'] ?? 'No subject').toString();
    final submitterName = (data['submittedByName'] ?? '').toString();
    final category = (data['category'] ?? 'app').toString();
    final status = (data['status'] ?? 'open').toString();
    final tripNumber = (data['tripNumber'] ?? '').toString();
    final csrAttempts = (data['csrAttempts'] as int?) ?? 0;
    final managerAttempts = (data['managerAttempts'] as int?) ?? 0;
    final createdAt = _parseTs(data['createdAt']);
    final updatedAt = _parseTs(data['updatedAt']);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AdminTheme.primary : AdminTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ticketNumber,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                _catChip(category),
                const Spacer(),
                _statusChip(status),
              ],
            ),
            if (tripNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 12,
                    color: AdminTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Trip $tripNumber',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 12,
                  color: AdminTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    submitterName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  _fmtDate(updatedAt ?? createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (status == 'pending' && csrAttempts > 0) ...[
              const SizedBox(height: 4),
              _attemptBar(csrAttempts, 5, 'CSR', Colors.orange),
            ],
            if ((status == 'escalated_manager' ||
                    status == 'escalated_presidential') &&
                managerAttempts > 0) ...[
              const SizedBox(height: 4),
              _attemptBar(managerAttempts, 3, 'Manager', Colors.deepOrange),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _attemptBar(int current, int max, String label, Color color) {
    return Row(
      children: [
        Icon(Icons.warning_amber_outlined, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '$label Attempt $current/$max',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  static Widget _catChip(String cat) {
    final isApp = cat == 'app';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isApp ? Colors.indigo : Colors.teal).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isApp ? 'App' : 'Logistics',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isApp ? Colors.indigo : Colors.teal,
        ),
      ),
    );
  }

  static Widget _statusChip(String status) {
    final (color, label) = _statusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static (Color, String) _statusMeta(String status) {
    switch (status) {
      case 'open':
        return (AdminTheme.statusActive, 'Open');
      case 'pending':
        return (AdminTheme.statusPending, 'Pending');
      case 'escalated_manager':
        return (Colors.deepOrange, 'Manager Queue');
      case 'escalated_presidential':
        return (Color(0xFFB71C1C), 'Presidential');
      case 'resolved':
        return (AdminTheme.statusCompleted, 'Resolved');
      default:
        return (AdminTheme.textSecondary, status);
    }
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket Detail Pane (right side)
// ─────────────────────────────────────────────────────────────────────────────

class _TicketDetailPane extends StatefulWidget {
  final String ticketId;
  final String role;
  final VoidCallback onClose;

  const _TicketDetailPane({
    required this.ticketId,
    required this.role,
    required this.onClose,
  });

  @override
  State<_TicketDetailPane> createState() => _TicketDetailPaneState();
}

class _TicketDetailPaneState extends State<_TicketDetailPane> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await AdminRepository.addAdminMessage(
      ticketId: widget.ticketId,
      body: text,
      senderName: _roleName(widget.role),
    );
    if (mounted) {
      setState(() => _sending = false);
      if (ok) {
        _replyCtrl.clear();
        _scrollToBottom();
      }
    }
  }

  Future<void> _showResolveDialog() async {
    final notesCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(
                'Mark as Resolved',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What resolved the issue?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 4,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Resolution Notes *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminTheme.statusActive,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (notesCtrl.text.trim().isEmpty) return;
                          setS(() => saving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          await AdminRepository.resolveTicket(
                            ticketId: widget.ticketId,
                            resolutionNotes: notesCtrl.text.trim(),
                            closedBy: _roleName(widget.role),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Ticket resolved.')),
                          );
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resolve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showNoDialog({
    required bool isManagerLevel,
    required int currentAttempts,
    required int maxAttempts,
  }) async {
    final remarksCtrl = TextEditingController();
    final remaining = maxAttempts - currentAttempts - 1;
    final willEscalate = remaining <= 0;
    final nextEscalation = isManagerLevel
        ? 'Presidential Appeal'
        : 'Manager Queue';

    await showDialog(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(
                willEscalate
                    ? 'Escalate to $nextEscalation'
                    : 'Attempt ${currentAttempts + 1}/$maxAttempts Failed',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (willEscalate)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isManagerLevel
                            ? '⚠️ Attempt $maxAttempts/$maxAttempts. This will escalate to Presidential Appeal. Only President/CEO or Corporate Lawyer may act after.'
                            : '⚠️ Attempt $maxAttempts/$maxAttempts. This will escalate to the Manager Queue.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.deepOrange,
                        ),
                      ),
                    )
                  else
                    Text(
                      isManagerLevel
                          ? '$remaining attempt(s) remaining before Presidential Appeal.'
                          : '$remaining attempt(s) remaining before Manager escalation.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Remarks *',
                      hintText: willEscalate
                          ? 'Explain why this is being escalated...'
                          : 'Describe what was attempted and why it failed...',
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: willEscalate
                        ? Colors.deepOrange
                        : AdminTheme.statusWarning,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (remarksCtrl.text.trim().isEmpty) return;
                          setS(() => saving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final actorRole = isManagerLevel
                              ? widget.role
                              : 'coordinator';
                          await AdminRepository.escalateTicket(
                            ticketId: widget.ticketId,
                            remarks: remarksCtrl.text.trim(),
                            actorRole: actorRole,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                willEscalate
                                    ? 'Ticket escalated to $nextEscalation.'
                                    : 'Attempt recorded. Ticket remains in queue.',
                              ),
                            ),
                          );
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          willEscalate
                              ? 'Escalate to $nextEscalation'
                              : 'Submit Failed Attempt',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AdminTheme.divider)),
        color: Colors.white,
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(widget.ticketId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || snap.data?.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final ticketNumber = (data['ticketNumber'] ?? '').toString();
          final subject = (data['subject'] ?? '').toString();
          final status = (data['status'] ?? 'open').toString();
          final category = (data['category'] ?? 'app').toString();
          final submitterName = (data['submittedByName'] ?? '').toString();
          final submitterType = (data['submittedByType'] ?? '').toString();
          final createdAt = _parseTs(data['createdAt']);
          final tripNumber = (data['tripNumber'] ?? '').toString();
          final csrAttempts = (data['csrAttempts'] as int?) ?? 0;
          final managerAttempts = (data['managerAttempts'] as int?) ?? 0;
          final isResolved = status == 'resolved';
          final resolutionNotes = (data['resolutionNotes'] ?? '').toString();
          final closedBy = (data['closedBy'] ?? '').toString();
          final escalationRemarks = (data['escalationRemarks'] ?? '')
              .toString();

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AdminTheme.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                ticketNumber,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AdminTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _catBadge(category),
                              const SizedBox(width: 8),
                              _statusBadge(status),
                            ],
                          ),
                          if (tripNumber.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 13,
                                  color: AdminTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Trip $tripNumber',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AdminTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            subject,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$submitterName · ${_submitterTypeLabel(submitterType)} · ${_fmtDate(createdAt)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Status banner
              _buildStatusBanner(
                status: status,
                csrAttempts: csrAttempts,
                managerAttempts: managerAttempts,
                resolutionNotes: resolutionNotes,
                closedBy: closedBy,
                escalationRemarks: escalationRemarks,
              ),

              // Messages thread
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: AdminRepository.streamTicketMessages(widget.ticketId),
                  builder: (context, msgSnap) {
                    final msgs = msgSnap.data?.docs ?? [];
                    _scrollToBottom();
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i].data() as Map<String, dynamic>;
                        final sType = (m['senderType'] ?? '').toString();
                        return _MessageBubble(
                          body: (m['body'] ?? '').toString(),
                          senderName: (m['senderName'] ?? '').toString(),
                          senderType: sType,
                          createdAt: _parseTs(m['createdAt']),
                          isAdmin: sType == 'admin',
                          isSystem: sType == 'system',
                        );
                      },
                    );
                  },
                ),
              ),

              // Action bar
              if (!isResolved) ...[
                const Divider(height: 1),
                _buildActionBar(
                  status: status,
                  csrAttempts: csrAttempts,
                  managerAttempts: managerAttempts,
                ),
              ],

              // Reopen (for resolved + manager-level roles)
              if (isResolved &&
                  (widget.role == 'admin' ||
                      widget.role == 'president' ||
                      widget.role == 'manager')) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await AdminRepository.reopenTicket(widget.ticketId);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Ticket reopened.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reopen Ticket'),
                  ),
                ),
              ],

              // Reply input
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        enabled: !isResolved,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isResolved
                              ? 'Ticket is resolved. Reopen to reply.'
                              : 'Reply as ${_roleName(widget.role)}...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendReply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: (!isResolved && !_sending) ? _sendReply : null,
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner({
    required String status,
    required int csrAttempts,
    required int managerAttempts,
    required String resolutionNotes,
    required String closedBy,
    required String escalationRemarks,
  }) {
    switch (status) {
      case 'resolved':
        return _BannerStrip(
          color: AdminTheme.statusActive,
          icon: Icons.check_circle_outline,
          text: 'Resolved by $closedBy — $resolutionNotes',
        );
      case 'pending':
        if (csrAttempts == 0) return const SizedBox.shrink();
        return _BannerStrip(
          color: AdminTheme.statusWarning,
          icon: Icons.hourglass_empty_outlined,
          text:
              'Pending — CSR Attempt $csrAttempts/5. ${5 - csrAttempts} remain before Manager escalation.',
        );
      case 'escalated_manager':
        return _BannerStrip(
          color: Colors.deepOrange,
          icon: Icons.warning_amber_outlined,
          text:
              '🔴 Manager Queue — 5 CSR attempts exhausted.'
              '${managerAttempts > 0 ? ' Manager Attempt $managerAttempts/3.' : ''}'
              '${escalationRemarks.isNotEmpty ? ' Remarks: $escalationRemarks' : ''}',
        );
      case 'escalated_presidential':
        return _BannerStrip(
          color: const Color(0xFFB71C1C),
          icon: Icons.gavel_outlined,
          text:
              '⚠️ PRESIDENTIAL APPEAL — 3 Manager attempts exhausted. Only President/CEO or Corporate Lawyer may act.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionBar({
    required String status,
    required int csrAttempts,
    required int managerAttempts,
  }) {
    // Presidential — locked unless admin/president
    if (status == 'escalated_presidential') {
      if (_canActOnPresidential(widget.role)) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(
                Icons.gavel_outlined,
                color: Color(0xFFB71C1C),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Presidential Appeal — President/CEO or Corporate Lawyer only.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                ),
                onPressed: _showResolveDialog,
                child: const Text('RESOLVE — Presidential'),
              ),
            ],
          ),
        );
      } else {
        return Container(
          color: const Color(0xFFFFEBEE),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: Color(0xFFB71C1C),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Presidential Appeal — Contact President/CEO or Corporate Lawyer.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // Manager Queue — locked for coordinator
    if (status == 'escalated_manager') {
      if (!_canActOnManagerQueue(widget.role)) {
        return Container(
          color: Colors.orange.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: Colors.deepOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manager Queue — Awaiting Manager attention.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return _yesNoBar(
        isManagerLevel: true,
        currentAttempts: managerAttempts,
        maxAttempts: 3,
      );
    }

    // Open / Pending
    return _yesNoBar(
      isManagerLevel: false,
      currentAttempts: csrAttempts,
      maxAttempts: 5,
    );
  }

  Widget _yesNoBar({
    required bool isManagerLevel,
    required int currentAttempts,
    required int maxAttempts,
  }) {
    final remaining = maxAttempts - currentAttempts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Did you resolve the issue?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (currentAttempts > 0)
                  Text(
                    '${isManagerLevel ? 'Manager' : 'CSR'} Attempt $currentAttempts/$maxAttempts — $remaining remain',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminTheme.statusActive,
            ),
            onPressed: _showResolveDialog,
            child: const Text('YES'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepOrange,
              side: const BorderSide(color: Colors.deepOrange),
            ),
            onPressed: () => _showNoDialog(
              isManagerLevel: isManagerLevel,
              currentAttempts: currentAttempts,
              maxAttempts: maxAttempts,
            ),
            child: const Text('NO'),
          ),
        ],
      ),
    );
  }

  static Widget _catBadge(String cat) {
    final isApp = cat == 'app';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isApp ? Colors.indigo : Colors.teal).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isApp ? 'App' : 'Logistics',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isApp ? Colors.indigo : Colors.teal,
        ),
      ),
    );
  }

  static Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'open':
        color = AdminTheme.statusActive;
        label = 'Open';
      case 'pending':
        color = AdminTheme.statusPending;
        label = 'Pending';
      case 'escalated_manager':
        color = Colors.deepOrange;
        label = 'Manager Queue';
      case 'escalated_presidential':
        color = const Color(0xFFB71C1C);
        label = 'Presidential';
      case 'resolved':
        color = AdminTheme.statusCompleted;
        label = 'Resolved';
      default:
        color = AdminTheme.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static String _submitterTypeLabel(String t) {
    switch (t) {
      case 'customer':
        return 'Customer';
      case 'rider':
        return 'Rider';
      case 'admin':
        return 'CSR / Admin';
      default:
        return t;
    }
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('MMM d, yyyy h:mm a').format(dt.toLocal());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String body;
  final String senderName;
  final String senderType;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool isSystem;

  const _MessageBubble({
    required this.body,
    required this.senderName,
    required this.senderType,
    required this.createdAt,
    required this.isAdmin,
    required this.isSystem,
  });

  @override
  Widget build(BuildContext context) {
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AdminTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('MMM d, h:mm a').format(createdAt!.toLocal()),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: Column(
          crossAxisAlignment: isAdmin
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAdmin ? AdminTheme.primary : AdminTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isAdmin ? 12 : 0),
                  bottomRight: Radius.circular(isAdmin ? 0 : 12),
                ),
                border: isAdmin ? null : Border.all(color: AdminTheme.divider),
              ),
              child: Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isAdmin ? Colors.white : AdminTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            if (createdAt != null)
              Text(
                DateFormat('h:mm a').format(createdAt!.toLocal()),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AdminTheme.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner strip
// ─────────────────────────────────────────────────────────────────────────────

class _BannerStrip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _BannerStrip({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
