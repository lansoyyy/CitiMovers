import 'dart:async';

import 'package:citimovers/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';

class DragonpayPaymentProcessingScreen extends StatefulWidget {
  final String bookingId;
  final String transactionId;
  final String paymentUrl;

  const DragonpayPaymentProcessingScreen({
    super.key,
    required this.bookingId,
    required this.transactionId,
    required this.paymentUrl,
  });

  @override
  State<DragonpayPaymentProcessingScreen> createState() =>
      _DragonpayPaymentProcessingScreenState();
}

class _DragonpayPaymentProcessingScreenState
    extends State<DragonpayPaymentProcessingScreen>
    with WidgetsBindingObserver {
  final PaymentService _paymentService = PaymentService();

  Timer? _pollTimer;
  bool _isChecking = false;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatusOnce();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStatusOnce();
    });
    _checkStatusOnce();
  }

  Future<void> _checkStatusOnce() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final updated = await _paymentService.refreshDragonpayTransactionStatus(
        transactionId: widget.transactionId,
      );

      if (!mounted) return;

      final newStatus = updated?.status ?? 'pending';
      setState(() => _status = newStatus);

      if (newStatus == 'success') {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }

      if (newStatus == 'failed' ||
          newStatus == 'cancelled' ||
          newStatus == 'voided' ||
          newStatus == 'chargeback' ||
          newStatus == 'refunded') {
        _pollTimer?.cancel();
        return;
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _openDragonpay() async {
    final uri = Uri.parse(widget.paymentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      UIHelpers.showErrorToast('Could not open Dragonpay payment page.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFinal = _status == 'success' ||
        _status == 'failed' ||
        _status == 'cancelled' ||
        _status == 'voided' ||
        _status == 'chargeback' ||
        _status == 'refunded';

    String title;
    String subtitle;
    Color color;

    if (_status == 'success') {
      title = 'Payment Confirmed';
      subtitle = 'Your payment was verified successfully.';
      color = AppColors.success;
    } else if (isFinal) {
      title = 'Payment Not Confirmed';
      subtitle =
          'We could not confirm payment yet. You can retry or check again later.';
      color = AppColors.primaryRed;
    } else {
      title = 'Verifying Payment';
      subtitle =
          'Keep this screen open. We will automatically verify your payment status.';
      color = AppColors.primaryBlue;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.verified, color: color, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Medium',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openDragonpay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Open Dragonpay',
                  style: TextStyle(fontFamily: 'Bold'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isChecking ? null : _checkStatusOnce,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: BorderSide(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _isChecking ? 'Checking...' : 'Check Status Now',
                  style: const TextStyle(fontFamily: 'Bold'),
                ),
              ),
              const Spacer(),
              if (isFinal && _status != 'success')
                Text(
                  'You can continue using the app. If you already paid, the payment will be confirmed automatically once verified.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
              if (isFinal && _status != 'success')
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Continue'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
