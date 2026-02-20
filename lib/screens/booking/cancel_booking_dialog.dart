import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../services/booking_service.dart';
import '../../models/booking_model.dart';

/// Cancel Booking Dialog for Passengers
/// Allows customers to cancel their bookings with a reason
class CancelBookingDialog extends StatefulWidget {
  final BookingModel booking;

  const CancelBookingDialog({
    super.key,
    required this.booking,
  });

  @override
  State<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<CancelBookingDialog> {
  final BookingService _bookingService = BookingService();
  String? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();
  bool _isCancelling = false;

  final List<String> _cancellationReasons = [
    'No longer need the delivery',
    'Found a cheaper alternative',
    'Change of plans',
    'Driver not available',
    'Long waiting time',
    'Other reason',
  ];

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  bool _canCancel() {
    // Can only cancel if booking is pending or accepted
    return widget.booking.status == 'pending' ||
        widget.booking.status == 'accepted';
  }

  String _getFinalReason() {
    if (_selectedReason == 'Other reason') {
      return _otherReasonController.text.trim().isEmpty
          ? 'Other'
          : _otherReasonController.text.trim();
    }
    return _selectedReason ?? 'No reason provided';
  }

  Future<void> _cancelBooking() async {
    if (_selectedReason == null) {
      UIHelpers.showErrorToast('Please select a cancellation reason');
      return;
    }

    if (_selectedReason == 'Other reason' &&
        _otherReasonController.text.trim().isEmpty) {
      UIHelpers.showErrorToast('Please provide a reason for cancellation');
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    final bookingId = widget.booking.bookingId;
    if (bookingId == null || bookingId.isEmpty) {
      UIHelpers.showErrorToast('Invalid booking ID');
      setState(() {
        _isCancelling = false;
      });
      return;
    }

    final reason = _getFinalReason();
    final success = await _bookingService.cancelBooking(bookingId, reason);

    if (mounted) {
      setState(() {
        _isCancelling = false;
      });

      if (success) {
        UIHelpers.showSuccessToast('Booking cancelled successfully');
        Navigator.pop(context, true);
      } else {
        UIHelpers.showErrorToast('Failed to cancel booking. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCancel()) {
      return _buildCannotCancelDialog();
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel_outlined,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cancel Booking',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'ID: ${widget.booking.bookingId}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const Divider(height: 24),

            // Warning Message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancelling this booking may affect your delivery schedule.',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cancellation Reasons
            const Text(
              'Reason for Cancellation',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            ...List.generate(_cancellationReasons.length, (index) {
              final reason = _cancellationReasons[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  title: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.primaryRed,
                ),
              );
            }),

            // Other Reason Text Field
            if (_selectedReason == 'Other reason') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherReasonController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Please specify your reason...',
                  hintStyle: const TextStyle(
                    color: AppColors.textHint,
                    fontFamily: 'Regular',
                  ),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryRed),
                  ),
                  counterStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: AppColors.textPrimary,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCancelling
                        ? null
                        : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(
                        color: AppColors.textSecondary.withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep Booking',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Medium',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCancelling ? null : _cancelBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Cancel Booking',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Bold',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCannotCancelDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cannot Cancel Booking',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const Divider(height: 24),

            // Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.block,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This booking cannot be cancelled',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current status: ${_getStatusText(widget.booking.status)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bookings can only be cancelled when they are in "Pending" or "Driver Assigned" status.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Bold',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Driver Assigned';
      case 'in_progress':
        return 'In Transit';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// Helper function to show cancel booking dialog
Future<bool?> showCancelBookingDialog(
    BuildContext context, BookingModel booking) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CancelBookingDialog(booking: booking),
  );
}
