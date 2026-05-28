import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/customer_profile_helper.dart';

class CustomerAccountTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const CustomerAccountTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Account Type',
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
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
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: const [
        DropdownMenuItem(
          value: AppConstants.customerAccountTypeCod,
          child: Text('Regular Customer (COD)'),
        ),
        DropdownMenuItem(
          value: AppConstants.customerAccountTypeWarehouseContract,
          child: Text('Warehouse Contract'),
        ),
      ],
      onChanged: onChanged,
      validator: (selected) {
        if (selected == null || selected.isEmpty) {
          return 'Please select an account type';
        }
        return null;
      },
    );
  }
}

class CustomerAccountTypeHelperText extends StatelessWidget {
  final String accountType;

  const CustomerAccountTypeHelperText({
    super.key,
    required this.accountType,
  });

  @override
  Widget build(BuildContext context) {
    final isContract =
        accountType == AppConstants.customerAccountTypeWarehouseContract;
    return Text(
      isContract
          ? 'Fixed contract rates with 30-day billing. Trip amounts are not shown in the app.'
          : 'Standard booking with rate calculator and wallet payment per trip.',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

String customerAccountTypeLabel(String accountType) {
  return CustomerProfileHelper.accountTypeLabel(accountType);
}
