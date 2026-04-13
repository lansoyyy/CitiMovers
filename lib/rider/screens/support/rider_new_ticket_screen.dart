import 'package:flutter/material.dart';
import '../../../services/support_ticket_service.dart';
import '../../../utils/app_colors.dart';

class RiderNewTicketScreen extends StatefulWidget {
  final String riderId;
  final String riderName;

  const RiderNewTicketScreen({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderNewTicketScreen> createState() => _RiderNewTicketScreenState();
}

class _RiderNewTicketScreenState extends State<RiderNewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'app';
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final ticket = await SupportTicketService().createTicket(
      submitterId: widget.riderId,
      submitterName: widget.riderName,
      submitterType: 'rider',
      subject: _subjectCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ticket != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${ticket.ticketNumber} submitted. Our team will respond shortly.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit ticket. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'New Support Ticket',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Category',
                style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _CategoryChip(
                    label: 'App Issue',
                    icon: Icons.phone_android_outlined,
                    selected: _category == 'app',
                    onTap: () => setState(() => _category = 'app'),
                  ),
                  const SizedBox(width: 12),
                  _CategoryChip(
                    label: 'Logistics Concern',
                    icon: Icons.local_shipping_outlined,
                    selected: _category == 'logistics',
                    onTap: () => setState(() => _category = 'logistics'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Subject',
                style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectCtrl,
                decoration: _inputDecoration('Brief summary of your concern'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
                style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Description',
                style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 6,
                decoration:
                    _inputDecoration('Describe your concern in detail...'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
                style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2)
                      : const Text(
                          'Submit Ticket',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 13, fontFamily: 'Regular', color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryRed.withValues(alpha: 0.08)
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryRed : AppColors.lightGrey,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    selected ? AppColors.primaryRed : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Medium',
                  color:
                      selected ? AppColors.primaryRed : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
