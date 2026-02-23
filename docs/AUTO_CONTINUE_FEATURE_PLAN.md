# Auto-Continue Booking Feature Implementation Plan

## Overview

This document outlines the implementation plan for an auto-continue booking feature in the CitiMovers app. This feature ensures that when drivers or customers have ongoing bookings/deliveries and accidentally close the app or if the app logs out, they will be redirected to continue their booking when they reopen the app.

## Feature Requirements

### Core Functionality
- Detect ongoing bookings for both drivers and customers
- Automatically redirect users to the appropriate screen to continue their booking
- Support both ride bookings and delivery bookings
- Handle various app states: app close, app logout, app background/foreground

### User Experience Goals
- Seamless continuation of ongoing bookings
- Clear visual feedback when resuming a booking
- No data loss during app state changes
- Minimal disruption to the user workflow

---

## Reference Implementation Analysis (SakayPH)

The reference app at `D:/Flutter Projects/para` implements this feature successfully. Key implementation details:

### 1. Auto-Login System
- **Location**: `lib/services/auth_service.dart`
- **Method**: `checkAutoLogin()` checks for stored user/driver sessions using GetStorage
- Returns user type ('user' or 'driver') and appropriate screen to navigate to

### 2. Active Booking Detection

#### Customer Side (HomeScreen)
- **Location**: `lib/screens/home/home_screen.dart`
- **Method**: `_checkActivePassengerBooking()`
- **Trigger**: Called in `initState()` and `didPopNext()`

**Active Booking Statuses for Customers:**
- `pending` - Searching for driver
- `accepted` - Driver accepted the booking
- `driverArriving` - Driver is on the way to pickup
- `inProgress` - Ride/delivery in progress

**Behavior:**
- Shows "Resuming your active ride..." or "Resuming your booking search..." SnackBar
- Navigates to `DriverTrackingScreen` for active rides
- Navigates to `SearchingDriverScreen` for pending bookings

#### Driver Side (DriverHomeScreen)
- **Location**: `lib/screens/drivers/home_screen.dart`
- **Method**: `_checkActiveDriverBooking()`
- **Trigger**: Called after driver data is loaded

**Active Booking Statuses for Drivers:**
- `accepted` - Driver accepted the booking
- `driverArriving` - Driver is on the way to pickup
- `inProgress` - Ride/delivery in progress

**Behavior:**
- Shows "Resuming your active ride..." SnackBar
- Navigates to `DriverRideTrackingScreen`

### 3. Booking Service Methods
- **`getUserBookings(String userId)`**: Returns stream of user bookings
- **`getDriverBookings(String driverId)`**: Returns stream of driver bookings
- Both query Firestore with `orderBy('createdAt', descending: true)`

### 4. Flag Mechanism
- `_hasCheckedActiveBooking` flag prevents multiple redundant checks
- Reset when user returns to home screen via `didPopNext()`

---

## CitiMovers Implementation Plan

### Phase 1: Data Model and Service Layer Updates

#### 1.1 Booking Status Enum
**File**: `lib/models/booking_model.dart`

Ensure the booking status enum includes all necessary states:
```dart
enum BookingStatus {
  pending,           // Waiting for driver to accept
  paymentPending,    // Waiting for payment completion
  driverAssigned,    // Driver assigned to booking
  headingToPickup,   // Driver heading to pickup location
  arrivedAtPickup,   // Driver arrived at pickup location
  inTransit,         // Delivery in progress
  completed,         // Booking completed
  cancelled,         // Booking cancelled
}
```

#### 1.2 Booking Service Methods
**File**: `lib/services/booking_service.dart`

Add or update the following methods:

##### `getActiveUserBookings(String userId)`
```dart
/// Get active bookings for a specific customer
/// Returns bookings with status: pending, driverAssigned, headingToPickup, inTransit
Stream<List<BookingModel>> getActiveUserBookings(String userId) {
  return _firestore
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', whereIn: [
        'pending',
        'driverAssigned',
        'headingToPickup',
        'arrivedAtPickup',
        'inTransit',
      ])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList());
}
```

##### `getActiveDriverBookings(String driverId)`
```dart
/// Get active bookings for a specific driver
/// Returns bookings with status: driverAssigned, headingToPickup, arrivedAtPickup, inTransit
Stream<List<BookingModel>> getActiveDriverBookings(String driverId) {
  return _firestore
      .collection('bookings')
      .where('assignedDriver', isEqualTo: driverId)
      .where('status', whereIn: [
        'driverAssigned',
        'headingToPickup',
        'arrivedAtPickup',
        'inTransit',
      ])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList());
}
```

##### `getPendingUserBookings(String userId)`
```dart
/// Get pending bookings (searching for driver) for a specific customer
Stream<List<BookingModel>> getPendingUserBookings(String userId) {
  return _firestore
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList());
}
```

---

### Phase 2: Customer Side Implementation

#### 2.1 Home Screen Updates
**File**: `lib/screens/home_screen.dart` or `lib/screens/tabs/home_tab.dart`

##### Add State Variables
```dart
bool _hasCheckedActiveBooking = false;
```

##### Add Method: `_checkActiveCustomerBooking()`
```dart
Future<void> _checkActiveCustomerBooking() async {
  if (_hasCheckedActiveBooking) {
    return;
  }
  _hasCheckedActiveBooking = true;

  try {
    final userId = AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    // Check for active bookings (driver assigned, in progress)
    final activeBookings = await BookingService()
        .getActiveUserBookings(userId)
        .first;

    if (activeBookings.isNotEmpty) {
      final booking = activeBookings.first;
      await _resumeActiveBooking(booking);
      return;
    }

    // Check for pending bookings (searching for driver)
    final pendingBookings = await BookingService()
        .getPendingUserBookings(userId)
        .first;

    if (pendingBookings.isNotEmpty) {
      final booking = pendingBookings.first;
      await _resumePendingBooking(booking);
    }
  } catch (e) {
    print('Error checking active customer booking: $e');
  }
}
```

##### Add Method: `_resumeActiveBooking()`
```dart
Future<void> _resumeActiveBooking(BookingModel booking) async {
  if (!mounted) return;

  // Show resuming message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: Colors.green,
      content: Text(
        'Resuming your delivery...',
        style: TextStyle(color: Colors.white),
      ),
      duration: Duration(seconds: 2),
    ),
  );

  await Future.delayed(const Duration(milliseconds: 800));

  if (!mounted) return;

  // Navigate to delivery tracking screen
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => DeliveryTrackingScreen(
        bookingId: booking.id,
        // Pass all necessary booking data
      ),
    ),
  );
}
```

##### Add Method: `_resumePendingBooking()`
```dart
Future<void> _resumePendingBooking(BookingModel booking) async {
  if (!mounted) return;

  // Show resuming message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: Colors.green,
      content: Text(
        'Resuming your booking search...',
        style: TextStyle(color: Colors.white),
      ),
      duration: Duration(seconds: 2),
    ),
  );

  await Future.delayed(const Duration(milliseconds: 800));

  if (!mounted) return;

  // Navigate to searching driver screen or booking status screen
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => SearchingDriverScreen(
        bookingId: booking.id,
        // Pass all necessary booking data
      ),
    ),
  );
}
```

##### Update `initState()`
```dart
@override
void initState() {
  super.initState();
  // ... existing initialization code
  
  // Check for active booking after a short delay
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkActiveCustomerBooking();
  });
}
```

##### Implement Route Awareness (Optional)
```dart
@override
void didPopNext() {
  // Called when returning to this screen from another screen
  super.didPopNext();
  
  // Reset flag to check for active booking again
  _hasCheckedActiveBooking = false;
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _checkActiveCustomerBooking();
    }
  });
}
```

---

### Phase 3: Driver Side Implementation

#### 3.1 Rider Home Screen Updates
**File**: `lib/rider/screens/rider_home_screen.dart`

##### Add State Variables
```dart
bool _hasCheckedActiveDriverBooking = false;
```

##### Add Method: `_checkActiveDriverBooking()`
```dart
Future<void> _checkActiveDriverBooking() async {
  if (_hasCheckedActiveDriverBooking) {
    return;
  }
  _hasCheckedActiveDriverBooking = true;

  try {
    final driverId = RiderAuthService.getCurrentDriverId();
    if (driverId == null || driverId.isEmpty) {
      return;
    }

    // Check for active bookings
    final activeBookings = await BookingService()
        .getActiveDriverBookings(driverId)
        .first;

    if (activeBookings.isEmpty) {
      return;
    }

    final booking = activeBookings.first;
    await _resumeActiveDriverBooking(booking);
  } catch (e) {
    print('Error checking active driver booking: $e');
  }
}
```

##### Add Method: `_resumeActiveDriverBooking()`
```dart
Future<void> _resumeActiveDriverBooking(BookingModel booking) async {
  if (!mounted) return;

  // Show resuming message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: Colors.green,
      content: Text(
        'Resuming your active delivery...',
        style: TextStyle(color: Colors.white),
      ),
      duration: Duration(seconds: 2),
    ),
  );

  await Future.delayed(const Duration(milliseconds: 800));

  if (!mounted) return;

  // Navigate to delivery progress screen
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => RiderDeliveryProgressScreen(
        bookingId: booking.id,
        // Pass all necessary booking data
      ),
    ),
  );
}
```

##### Update `initState()`
```dart
@override
void initState() {
  super.initState();
  // ... existing initialization code
  
  // Check for active booking after driver data is loaded
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkActiveDriverBooking();
  });
}
```

---

### Phase 4: Splash Screen Integration

#### 4.1 Customer Splash Screen
**File**: `lib/screens/splash_screen.dart`

Ensure the splash screen properly handles auto-login and redirects to home screen where active booking check will occur.

#### 4.2 Driver Splash Screen
**File**: `lib/rider/screens/auth/rider_splash_screen.dart`

Ensure the splash screen properly handles auto-login and redirects to driver home screen where active booking check will occur.

---

### Phase 5: App Lifecycle Handling

#### 5.1 App State Observer
**File**: `lib/main.dart` or create new `lib/utils/app_lifecycle_observer.dart`

```dart
class AppLifecycleObserver extends WidgetsBindingObserver {
  final BuildContext context;
  final String userType; // 'customer' or 'driver'

  AppLifecycleObserver({required this.context, required this.userType});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground - check for active bookings
        _checkActiveBookingsOnResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - no action needed
        break;
    }
  }

  void _checkActiveBookingsOnResume() {
    // Navigate to home screen which will check for active bookings
    if (userType == 'customer') {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/rider_home', (route) => false);
    }
  }
}
```

---

### Phase 6: Session Persistence

#### 6.1 Ensure Session Data is Persisted
**File**: `lib/services/auth_service.dart` and `lib/rider/services/rider_auth_service.dart`

Verify that user/driver session data is persisted using SharedPreferences or GetStorage:

```dart
// Customer session
static Future<void> saveUserSession(UserModel user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('userId', user.id);
  await prefs.setString('userPhoneNumber', user.phoneNumber);
  await prefs.setString('userName', user.name);
}

// Driver session
static Future<void> saveDriverSession(RiderModel driver) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('driverId', driver.id);
  await prefs.setString('driverPhoneNumber', driver.phoneNumber);
  await prefs.setString('driverName', driver.name);
}
```

---

### Phase 7: Edge Cases and Error Handling

#### 7.1 Multiple Active Bookings
- Handle case where user has multiple active bookings (shouldn't happen but defensive coding)
- Use the most recent booking (ordered by `createdAt` descending)

#### 7.2 Stale Bookings
- Consider adding a timeout mechanism for stale bookings
- If a booking has been in the same status for too long, consider it stale

#### 7.3 Network Errors
- Handle network errors gracefully when checking for active bookings
- Show appropriate error messages to users

#### 7.4 Booking Status Mismatch
- Handle case where booking status changes during the check
- Ensure navigation happens only if booking is still in active state

#### 7.5 Data Loading States
- Show loading indicators while checking for active bookings
- Handle cases where driver/customer data is not fully loaded

---

### Phase 8: Testing Plan

#### 8.1 Customer Side Tests
- [ ] Test with pending booking (searching for driver)
- [ ] Test with driver assigned booking
- [ ] Test with driver heading to pickup
- [ ] Test with delivery in progress
- [ ] Test with no active bookings
- [ ] Test app close and reopen
- [ ] Test app logout and login
- [ ] Test app background and foreground

#### 8.2 Driver Side Tests
- [ ] Test with driver assigned booking
- [ ] Test with heading to pickup
- [ ] Test with arrived at pickup
- [ ] Test with delivery in progress
- [ ] Test with no active bookings
- [ ] Test app close and reopen
- [ ] Test app logout and login
- [ ] Test app background and foreground

#### 8.3 Edge Case Tests
- [ ] Test with network errors
- [ ] Test with slow network
- [ ] Test with multiple bookings
- [ ] Test with stale bookings
- [ ] Test with booking status changes during check

---

### Phase 9: UI/UX Enhancements

#### 9.1 Visual Feedback
- Add loading indicator while checking for active bookings
- Show appropriate messages for different booking states
- Use consistent color scheme (green for success/resuming)

#### 9.2 User Notifications
- Consider adding push notifications for booking status changes
- Show in-app notifications when returning to app with active booking

#### 9.3 Animation
- Add smooth transitions when resuming bookings
- Consider adding a progress indicator for the resuming process

---

## Implementation Checklist

### Customer Side
- [ ] Update `BookingService` with `getActiveUserBookings()` method
- [ ] Update `BookingService` with `getPendingUserBookings()` method
- [ ] Add `_hasCheckedActiveBooking` flag to home screen
- [ ] Implement `_checkActiveCustomerBooking()` method
- [ ] Implement `_resumeActiveBooking()` method
- [ ] Implement `_resumePendingBooking()` method
-- [ ] Update `initState()` to call check method
- [ ] Implement `didPopNext()` for route awareness (optional)
- [ ] Test all customer scenarios

### Driver Side
- [ ] Update `BookingService` with `getActiveDriverBookings()` method
- [ ] Add `_hasCheckedActiveDriverBooking` flag to rider home screen
- [ ] Implement `_checkActiveDriverBooking()` method
- [ ] Implement `_resumeActiveDriverBooking()` method
- [ ] Update `initState()` to call check method
- [ ] Implement `didPopNext()` for route awareness (optional)
- [ ] Test all driver scenarios

### Shared
- [ ] Verify session persistence in auth services
- [ ] Implement app lifecycle observer (optional)
- [ ] Add error handling for all scenarios
- [ ] Add loading indicators
- [ ] Test edge cases
- [ ] Update documentation

---

## Success Criteria

1. ✅ Customers with active bookings are automatically redirected to tracking screen
2. ✅ Customers with pending bookings are automatically redirected to search screen
3. ✅ Drivers with active bookings are automatically redirected to delivery progress screen
4. ✅ Feature works after app close and reopen
5. ✅ Feature works after app logout and login
6. ✅ Feature works when app returns from background
7. ✅ No data loss during state transitions
8. ✅ Clear visual feedback provided to users
9. ✅ Edge cases handled gracefully
10. ✅ All test scenarios pass

---

## Notes

- This implementation follows the pattern from the reference app (SakayPH)
- The flag mechanism prevents redundant checks
- Route awareness ensures booking check happens when returning to home screen
- Consider adding analytics to track how often this feature is used
- Consider adding user settings to disable auto-continue (optional)
