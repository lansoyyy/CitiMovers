import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../../services/payment_service.dart';
import '../../services/rider_auth_service.dart';

class RiderPaymentMethodsScreen extends StatefulWidget {
  const RiderPaymentMethodsScreen({super.key});

  @override
  State<RiderPaymentMethodsScreen> createState() =>
      _RiderPaymentMethodsScreenState();
}

class _RiderPaymentMethodsScreenState extends State<RiderPaymentMethodsScreen> {
  final _authService = RiderAuthService();
  final _paymentService = PaymentService();
  Stream<List<PaymentMethod>>? _paymentMethodsStream;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  void _loadPaymentMethods() {
    final rider = _authService.currentRider;
    if (rider != null) {
      setState(() {
        _paymentMethodsStream =
            _paymentService.getPaymentMethods(rider.riderId);
      });
    }
  }

  void _showAddPaymentMethodDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddPaymentMethodSheet(
        onPaymentMethodAdded: () {
          // Stream will automatically update
          UIHelpers.showSuccessToast('Payment method added');
        },
      ),
    );
  }

  void _setDefaultPaymentMethod(String id) async {
    final success = await _paymentService.setDefaultPaymentMethod(id);
    if (success) {
      UIHelpers.showSuccessToast('Default payment method updated');
    } else {
      UIHelpers.showErrorToast('Failed to update default payment method');
    }
  }

  void _deletePaymentMethod(String id) async {
    final success = await _paymentService.deletePaymentMethod(id);
    if (success) {
      UIHelpers.showSuccessToast('Payment method deleted');
    } else {
      UIHelpers.showErrorToast(
          'Cannot delete default payment method or method not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add your bank account or e-wallet to receive your earnings',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment Methods List
              if (_paymentMethodsStream != null)
                StreamBuilder<List<PaymentMethod>>(
                  stream: _paymentMethodsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error loading payment methods'),
                      );
                    }

                    final paymentMethods = snapshot.data ?? [];

                    if (paymentMethods.isEmpty) {
                      return Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 80,
                              color: AppColors.lightGrey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Payment Methods',
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add a payment method to receive your earnings',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Regular',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: paymentMethods.map((method) {
                        return _PaymentMethodCard(
                          method: method,
                          onSetDefault: () =>
                              _setDefaultPaymentMethod(method.id),
                          onDelete: () => _deletePaymentMethod(method.id),
                        );
                      }).toList(),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Add Payment Method Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _showAddPaymentMethodDialog,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    side:
                        const BorderSide(color: AppColors.primaryRed, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _PaymentMethodCard({
    required this.method,
    required this.onSetDefault,
    required this.onDelete,
  });

  IconData _getIcon() {
    switch (method.type) {
      case 'bank':
        return FontAwesomeIcons.buildingColumns;
      case 'gcash':
        return FontAwesomeIcons.mobileScreen;
      case 'paymaya':
        return FontAwesomeIcons.mobileScreen;
      default:
        return FontAwesomeIcons.wallet;
    }
  }

  Color _getColor() {
    switch (method.type) {
      case 'bank':
        return AppColors.primaryBlue;
      case 'gcash':
        return const Color(0xFF007DFF);
      case 'paymaya':
        return const Color(0xFF00B14F);
      default:
        return AppColors.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: method.isDefault
            ? Border.all(color: AppColors.primaryRed, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(),
                  color: _getColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          method.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (method.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Bold',
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method.accountNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'default') {
                    onSetDefault();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (!method.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 12),
                          Text('Set as Default'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 20, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            method.accountName,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Medium',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPaymentMethodSheet extends StatefulWidget {
  final VoidCallback onPaymentMethodAdded;

  const _AddPaymentMethodSheet({
    required this.onPaymentMethodAdded,
  });

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  String _selectedType = 'bank';
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _paymentService = PaymentService();
  final _authService = RiderAuthService();
  bool _isLoading = false;

  Future<void> _savePaymentMethod() async {
    final rider = _authService.currentRider;
    if (rider == null) return;

    final name = _nameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountName = _accountNameController.text.trim();

    if (name.isEmpty || accountNumber.isEmpty || accountName.isEmpty) {
      UIHelpers.showErrorToast('Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _paymentService.addPaymentMethod(
        userId: rider.riderId,
        type: _selectedType,
        name: name,
        accountNumber: accountNumber,
        accountName: accountName,
        isDefault:
            false, // Can add logic to set as first payment method as default
      );

      if (success) {
        Navigator.pop(context);
        widget.onPaymentMethodAdded();
      } else {
        UIHelpers.showErrorToast('Failed to add payment method');
      }
    } catch (e) {
      UIHelpers.showErrorToast('Error adding payment method');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Add Payment Method',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 24),

              // Payment Type Selection
              Row(
                children: [
                  Expanded(
                    child: _PaymentTypeChip(
                      icon: FontAwesomeIcons.buildingColumns,
                      label: 'Bank',
                      isSelected: _selectedType == 'bank',
                      onTap: () => setState(() => _selectedType = 'bank'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentTypeChip(
                      icon: FontAwesomeIcons.mobileScreen,
                      label: 'GCash',
                      isSelected: _selectedType == 'gcash',
                      onTap: () => setState(() => _selectedType = 'gcash'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentTypeChip(
                      icon: FontAwesomeIcons.mobileScreen,
                      label: 'PayMaya',
                      isSelected: _selectedType == 'paymaya',
                      onTap: () => setState(() => _selectedType = 'paymaya'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Form Fields
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText:
                      _selectedType == 'bank' ? 'Bank Name' : 'Account Name',
                  prefixIcon: const Icon(Icons.account_balance),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _accountNumberController,
                decoration: InputDecoration(
                  labelText: _selectedType == 'bank'
                      ? 'Account Number'
                      : 'Mobile Number',
                  prefixIcon: const Icon(Icons.numbers),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                ),
              ),

              const SizedBox(height: 24),

              // Add Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePaymentMethod,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.white)
                      : const Text(
                          'Add Payment Method',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentTypeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed.withValues(alpha: 0.1)
              : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isSelected ? AppColors.primaryRed : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Bold',
                color:
                    isSelected ? AppColors.primaryRed : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
