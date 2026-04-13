import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/support_ticket_model.dart';
import '../../../services/support_ticket_service.dart';
import '../../../utils/app_colors.dart';

class RiderTicketDetailScreen extends StatefulWidget {
  final SupportTicketModel ticket;
  final String riderId;
  final String riderName;

  const RiderTicketDetailScreen({
    super.key,
    required this.ticket,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderTicketDetailScreen> createState() =>
      _RiderTicketDetailScreenState();
}

class _RiderTicketDetailScreenState extends State<RiderTicketDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _service = SupportTicketService();
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
    await _service.addMessage(
      ticketId: widget.ticket.ticketId,
      senderId: widget.riderId,
      senderType: 'rider',
      senderName: widget.riderName,
      body: text,
    );
    if (mounted) {
      setState(() => _sending = false);
      _replyCtrl.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              ticket.ticketNumber,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: AppColors.primaryRed,
              ),
            ),
            Text(
              ticket.subject,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _statusBanner(ticket),
          Expanded(
            child: StreamBuilder<List<SupportTicketMessageModel>>(
              stream: _service.streamTicketMessages(ticket.ticketId),
              builder: (context, snap) {
                final msgs = snap.data ?? [];
                _scrollToBottom();

                if (msgs.isEmpty &&
                    snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryRed),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isMine = msg.senderId == widget.riderId;
                    return _MessageBubble(msg: msg, isMine: isMine);
                  },
                );
              },
            ),
          ),
          if (ticket.status != 'resolved') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Regular',
                            color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.lightGrey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.lightGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryRed, width: 1.5),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendReply,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  color: AppColors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send,
                              color: AppColors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: AppColors.scaffoldBackground,
              child: const Text(
                'This ticket has been resolved. Thank you!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Medium',
                    color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _statusBanner(SupportTicketModel ticket) {
    if (ticket.status == 'resolved') {
      return _Banner(
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_outline,
        text: ticket.resolutionNotes?.isNotEmpty == true
            ? 'Resolved: ${ticket.resolutionNotes}'
            : 'This ticket has been resolved.',
      );
    }
    if (ticket.isEscalated) {
      return _Banner(
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_outlined,
        text: ticket.escalationRemarks?.isNotEmpty == true
            ? 'Escalated: ${ticket.escalationRemarks}'
            : 'This ticket has been escalated for further review.',
      );
    }
    if (ticket.status == 'pending') {
      return _Banner(
        color: const Color(0xFFF59E0B),
        icon: Icons.hourglass_top_outlined,
        text: 'Awaiting response from our support team.',
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(fontSize: 12, fontFamily: 'Medium', color: color),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportTicketMessageModel msg;
  final bool isMine;

  const _MessageBubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final isAdmin = msg.senderType == 'admin';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Support',
                          style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Bold',
                              color: AppColors.white)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    msg.senderName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Bold',
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primaryRed : AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 0),
                  bottomRight: Radius.circular(isMine ? 0 : 14),
                ),
                border: isMine ? null : Border.all(color: AppColors.lightGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.body,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: isMine ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                DateFormat('h:mm a').format(msg.createdAt.toLocal()),
                style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
