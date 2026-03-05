# Offline Mode Implementation Guide

## Overview

The CitiMovers app now includes a comprehensive offline mode system that ensures seamless operation even with weak or no internet connection. This system provides:

1. **10-minute delayed reporting** - Data is saved locally and uploaded to cloud every 10 minutes
2. **Automatic retry on failure** - Failed uploads are retried with exponential backoff
3. **Connectivity-based sync** - Immediate sync when connection is restored
4. **Visual offline indicators** - Users can see when they're offline and pending operations

## Architecture

### Core Services

#### 1. OfflineService (`lib/services/offline_service.dart`)

**Purpose:** Global offline service for queuing and executing operations when offline.

**Features:**
- Connectivity monitoring
- Operation queuing with retry logic
- Local caching with expiration
- Automatic sync when online

**Operation Types:**
- `createBooking` - Queue booking creation
- `updateBookingStatus` - Queue status updates
- `uploadImage` - Queue image uploads (profile, delivery, documents)
- `updateProfile` - Queue profile updates

**Usage Example:**
```dart
final offlineService = OfflineService();

// Queue a booking status update
await offlineService.queueOperation(OfflineOperation(
  id: 'unique_id',
  type: OfflineOperationType.updateBookingStatus,
  data: {
    'bookingId': 'booking_123',
    'status': 'picked_up',
    'driverId': 'driver_456',
  },
  createdAt: DateTime.now(),
));
```

#### 2. DeliveryQueueService (`lib/services/delivery_queue_service.dart`)

**Purpose:** Specialized queue for delivery-related operations from Pick-up Arrival onwards.

**Features:**
- 10-minute periodic sync timer
- Connectivity-based immediate sync
- Local file storage in persistent directory
- Photo upload queuing with retry
- Status update queuing

**Key Methods:**
```dart
// Start the queue service (call in initState)
await DeliveryQueueService.instance.start();

// Queue a photo upload
await DeliveryQueueService.instance.enqueuePhotoUpload(
  bookingId: 'booking_123',
  storageStage: 'Start Loading',
  firestoreStage: 'start_loading',
  localFilePath: '/path/to/photo.jpg',
);

// Queue a status update
await DeliveryQueueService.instance.enqueueStatusUpdate(
  bookingId: 'booking_123',
  status: 'loading',
  subStep: 'start_loading',
);

// Force sync for a specific booking
await DeliveryQueueService.instance.forceSyncForBooking('booking_123');

// Stop the queue service (call in dispose)
DeliveryQueueService.instance.stop();
```

#### 3. RetryUtility (`lib/utils/retry_utility.dart`)

**Purpose:** Provides exponential backoff retry logic for transient failures.

**Features:**
- Configurable max attempts
- Exponential backoff delay
- Network error detection
- Timeout handling

**Usage Example:**
```dart
final result = await RetryUtility.retryUploadOperation(() async {
  return await uploadToCloud(file);
});
```

### UI Components

#### 1. OfflineModeIndicator

Shows a compact indicator when offline with pending count.

```dart
OfflineModeIndicator(
  showPendingCount: true,
  onTap: () {
    // Handle tap - show more details
  },
)
```

#### 2. OfflineBanner

Full-width banner that appears at the top of the screen when offline.

```dart
OfflineBanner(
  message: 'You are offline. Data will sync when connection is restored.',
  dismissible: true,
  onDismiss: () {
    // Handle dismiss
  },
)
```

#### 3. ConnectivityStatusIcon

Small icon showing current connectivity status.

```dart
ConnectivityStatusIcon(
  size: 24,
  showLabel: false, // or true to show "Online"/"Offline" text
)
```

## Implementation Details

### 10-Minute Upload Scheduling

The `DeliveryQueueService` implements the 10-minute upload scheduling:

```dart
// In DeliveryQueueService.start()
_syncTimer = Timer.periodic(
  const Duration(minutes: syncIntervalMinutes), // 10 minutes
  (_) {
    debugPrint('[DeliveryQueue] 10-min timer fired — flushing queue.');
    _flush();
  },
);
```

### Automatic Retry on Failure

Failed uploads are automatically retried with exponential backoff:

- **Max attempts:** 5
- **Initial delay:** 1 second
- **Backoff multiplier:** 2.0
- **Max delay:** 30 seconds
- **Total timeout:** 3 minutes

### Connectivity-Based Sync

When connectivity is restored, the queue is flushed immediately:

```dart
// In DeliveryQueueService.start()
_connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
  if (result != ConnectivityResult.none) {
    debugPrint('[DeliveryQueue] Connectivity restored — flushing queue.');
    _flush();
  }
});
```

### Local File Storage

Photos are saved to a persistent directory that survives app restarts:

```dart
// Get the local delivery directory
final deliveryDir = await DeliveryQueueService.getLocalDeliveryDir();
// Returns: /data/app/com.citimovers/files/delivery_uploads/
```

## Integration Guide

### For Rider/Delivery Screens

1. **Initialize the queue in `initState()`:**
```dart
@override
void initState() {
  super.initState();
  _deliveryQueue.start();
  _registerQueueCallbacks();
}
```

2. **Queue photo uploads:**
```dart
// Save photo to local directory
final deliveryDir = await DeliveryQueueService.getLocalDeliveryDir();
final file = await File('$deliveryDir/photo_${timestamp}.jpg').writeAsBytes(bytes);

// Queue for upload
await _deliveryQueue.enqueuePhotoUpload(
  bookingId: widget.bookingId,
  storageStage: 'Start Loading',
  firestoreStage: 'start_loading',
  localFilePath: file.path,
);
```

3. **Queue status updates:**
```dart
await _deliveryQueue.enqueueStatusUpdate(
  bookingId: widget.bookingId,
  status: 'loading',
  subStep: 'start_loading',
);
```

4. **Stop the queue in `dispose()`:**
```dart
@override
void dispose() {
  _deliveryQueue.stop();
  super.dispose();
}
```

### For Customer Screens

1. **Add offline indicator to UI:**
```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      OfflineBanner(
        message: 'You are offline. Updates may be delayed.',
      ),
      // Your content
    ],
  );
}
```

2. **Show connectivity status in app bar:**
```dart
AppBar(
  title: Text('My Bookings'),
  actions: [
    ConnectivityStatusIcon(size: 20),
  ],
)
```

### For Global Offline Operations

Use `OfflineService` for operations that should work offline anywhere in the app:

```dart
// Queue a booking creation
await OfflineService().queueOperation(OfflineOperation(
  id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
  type: OfflineOperationType.createBooking,
  data: {
    'booking': bookingData.toJson(),
  },
  createdAt: DateTime.now(),
));

// Queue a profile update
await OfflineService().queueOperation(OfflineOperation(
  id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
  type: OfflineOperationType.updateProfile,
  data: {
    'userId': userId,
    'updates': {'name': 'John Doe', 'phone': '+1234567890'},
  },
  createdAt: DateTime.now(),
));
```

## Testing

### Test Offline Mode

1. **Disable internet connection** on your device/emulator
2. **Perform actions** (create booking, upload photo, update status)
3. **Verify data is saved locally** (check pending operations)
4. **Enable internet connection**
5. **Verify data syncs to cloud** automatically

### Test 10-Minute Timer

1. **Disable internet connection**
2. **Queue several operations**
3. **Enable internet connection**
4. **Wait for 10 minutes** (or modify `syncIntervalMinutes` for testing)
5. **Verify all operations are synced**

### Test Retry Mechanism

1. **Use unstable network** (slow, intermittent)
2. **Queue operations**
3. **Monitor logs** for retry attempts
4. **Verify exponential backoff** (1s, 2s, 4s, 8s, 16s)

## Configuration

### Adjust Sync Interval

Modify `syncIntervalMinutes` in `DeliveryQueueService`:

```dart
static const int syncIntervalMinutes = 10; // Change to desired value
```

### Adjust Retry Parameters

Modify retry parameters in `RetryUtility.retryUploadOperation()`:

```dart
static Future<T> retryUploadOperation<T>(Future<T> Function() fn) {
  return retry<T>(
    fn: fn,
    maxAttempts: 5, // Change max attempts
    initialDelay: const Duration(seconds: 1), // Change initial delay
    backoffMultiplier: 2.0, // Change backoff multiplier
    maxDelay: const Duration(seconds: 30), // Change max delay
    retryIf: (error) {
      // Customize retry conditions
      final errorString = error.toString().toLowerCase();
      return errorString.contains('network') ||
          errorString.contains('timeout') ||
          errorString.contains('connection');
    },
  );
}
```

## Troubleshooting

### Operations Not Syncing

1. **Check connectivity status:**
```dart
final isOnline = OfflineService().isOnline;
print('Is online: $isOnline');
```

2. **Check pending operations:**
```dart
final operations = await OfflineService().getPendingOperations();
print('Pending operations: ${operations.length}');
```

3. **Force sync:**
```dart
await OfflineService().syncNow();
```

### Photos Not Uploading

1. **Check if file exists:**
```dart
final file = File(localPath);
print('File exists: ${file.existsSync()}');
```

2. **Check delivery queue status:**
```dart
final pending = await DeliveryQueueService.instance.pendingCountForBooking(bookingId);
print('Pending uploads: $pending');
```

3. **Force sync for booking:**
```dart
await DeliveryQueueService.instance.forceSyncForBooking(bookingId);
```

### UI Not Updating

1. **Ensure widgets are listening to streams:**
```dart
StreamBuilder<bool>(
  stream: OfflineService().connectivityStream,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? true;
    return Text(isOnline ? 'Online' : 'Offline');
  },
)
```

2. **Check ValueNotifier for delivery queue:**
```dart
ValueListenableBuilder<int>(
  valueListenable: DeliveryQueueService.instance.pendingCountNotifier,
  builder: (context, count, child) {
    return Text('$count pending');
  },
)
```

## Best Practices

1. **Always queue operations** that should work offline
2. **Show offline indicators** to users when they're offline
3. **Handle pending operations** gracefully (show count, allow manual sync)
4. **Test with poor connectivity** to ensure robustness
5. **Monitor logs** for sync issues during development
6. **Use persistent storage** for files that need to survive app restarts

## Summary

The offline mode implementation ensures:

✅ **Seamless driver experience** - Drivers can continue working offline
✅ **Complete reporting** - All data is saved locally and synced later
✅ **Automatic retry** - Failed uploads are retried with exponential backoff
✅ **10-minute sync** - Data is uploaded to cloud every 10 minutes
✅ **Connectivity trigger** - Immediate sync when connection is restored
✅ **Visual feedback** - Users can see offline status and pending operations
✅ **Customer visibility** - Updates reflect on customer side after successful sync

This provides a complete offline-first experience that works reliably even with weak signal.
