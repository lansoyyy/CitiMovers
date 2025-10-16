import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'app_colors.dart';

/// UI Helper utilities for CitiMovers
class UIHelpers {
  UIHelpers._();

  /// Show loading indicator with flutter_spinkit
  static Widget loadingIndicator({
    Color? color,
    double size = 50.0,
  }) {
    return SpinKitFadingCircle(
      color: color ?? AppColors.primaryRed,
      size: size,
    );
  }

  /// Show loading indicator with custom animation
  static Widget loadingSpinner({
    Color? color,
    double size = 50.0,
  }) {
    return SpinKitCircle(
      color: color ?? AppColors.primaryBlue,
      size: size,
    );
  }

  /// Show rotating circle loading indicator
  static Widget loadingRotatingCircle({
    Color? color,
    double size = 50.0,
  }) {
    return SpinKitRotatingCircle(
      color: color ?? AppColors.primaryRed,
      size: size,
    );
  }

  /// Show wave loading indicator
  static Widget loadingWave({
    Color? color,
    double size = 50.0,
  }) {
    return SpinKitWave(
      color: color ?? AppColors.primaryBlue,
      size: size,
    );
  }

  /// Show three bounce loading indicator
  static Widget loadingThreeBounce({
    Color? color,
    double size = 30.0,
  }) {
    return SpinKitThreeBounce(
      color: color ?? AppColors.primaryRed,
      size: size,
    );
  }

  /// Show full screen loading overlay
  static Widget loadingOverlay({
    String? message,
    Color? backgroundColor,
  }) {
    return Container(
      color: backgroundColor ?? Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loadingIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontFamily: 'Medium',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show success toast message
  static void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppColors.success,
      textColor: AppColors.white,
      fontSize: 14.0,
    );
  }

  /// Show error toast message
  static void showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: AppColors.error,
      textColor: AppColors.white,
      fontSize: 14.0,
    );
  }

  /// Show info toast message
  static void showInfoToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppColors.info,
      textColor: AppColors.white,
      fontSize: 14.0,
    );
  }

  /// Show warning toast message
  static void showWarningToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: AppColors.warning,
      textColor: AppColors.black,
      fontSize: 14.0,
    );
  }

  /// Show custom toast message
  static void showToast(
    String message, {
    Toast length = Toast.LENGTH_SHORT,
    ToastGravity gravity = ToastGravity.BOTTOM,
    Color? backgroundColor,
    Color? textColor,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: length,
      gravity: gravity,
      timeInSecForIosWeb: 2,
      backgroundColor: backgroundColor ?? AppColors.darkGrey,
      textColor: textColor ?? AppColors.white,
      fontSize: 14.0,
    );
  }

  /// Show snackbar with action
  static void showSnackBar(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Regular',
            fontSize: 14,
          ),
        ),
        duration: duration,
        backgroundColor: backgroundColor ?? AppColors.darkGrey,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primaryBlue,
                onPressed: onAction ?? () {},
              )
            : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show bottom sheet loading
  static void showLoadingBottomSheet(BuildContext context, {String? message}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loadingIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Medium',
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              loadingIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
