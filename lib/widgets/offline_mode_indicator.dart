import 'package:flutter/material.dart';
import 'package:citimovers/services/offline_service.dart';
import 'package:citimovers/utils/app_colors.dart';

/// Offline Mode Indicator Widget
///
/// Shows a visual indicator when the app is in offline mode.
/// Displays pending operations count and sync status.
class OfflineModeIndicator extends StatefulWidget {
  final bool showPendingCount;
  final VoidCallback? onTap;

  const OfflineModeIndicator({
    super.key,
    this.showPendingCount = true,
    this.onTap,
  });

  @override
  State<OfflineModeIndicator> createState() => _OfflineModeIndicatorState();
}

class _OfflineModeIndicatorState extends State<OfflineModeIndicator> {
  final OfflineService _offlineService = OfflineService();
  bool _isOnline = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Get initial status
    setState(() {
      _isOnline = _offlineService.isOnline;
    });

    // Listen to connectivity changes
    _offlineService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });

    // Get pending operations count
    _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final operations = await _offlineService.getPendingOperations();
    if (mounted) {
      setState(() {
        _pendingCount = operations.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if online and no pending operations
    if (_isOnline && _pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isOnline ? AppColors.warning : AppColors.error,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.sync : Icons.cloud_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isOnline ? 'Syncing...' : 'Offline Mode',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.showPendingCount && _pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingCount pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline Banner Widget
///
/// A full-width banner that appears at the top of the screen when offline.
/// Can be dismissed by the user.
class OfflineBanner extends StatefulWidget {
  final String? message;
  final bool dismissible;
  final VoidCallback? onDismiss;

  const OfflineBanner({
    super.key,
    this.message,
    this.dismissible = true,
    this.onDismiss,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final OfflineService _offlineService = OfflineService();
  bool _isOnline = true;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Get initial status
    setState(() {
      _isOnline = _offlineService.isOnline;
    });

    // Listen to connectivity changes
    _offlineService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _isDismissed = false; // Reset dismissal when status changes
        });
      }
    });
  }

  void _handleDismiss() {
    setState(() {
      _isDismissed = true;
    });
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if online, dismissed, or not dismissible
    if (_isOnline || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.message ??
                  'You are offline. Some features may be limited.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.dismissible)
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _handleDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Connectivity Status Icon
///
/// A small icon that shows the current connectivity status.
/// Useful for placing in app bars or status bars.
class ConnectivityStatusIcon extends StatelessWidget {
  final double size;
  final bool showLabel;

  const ConnectivityStatusIcon({
    super.key,
    this.size = 24,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineService().connectivityStream,
      initialData: OfflineService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (!showLabel) {
          return Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline ? AppColors.success : AppColors.error,
            size: size,
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: isOnline ? AppColors.success : AppColors.error,
              size: size,
            ),
            const SizedBox(width: 4),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: isOnline ? AppColors.success : AppColors.error,
                fontSize: size * 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
