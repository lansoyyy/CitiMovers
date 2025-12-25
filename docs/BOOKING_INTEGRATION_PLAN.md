# CitiMovers Booking Process Integration Plan

## Overview

This document outlines the comprehensive Firebase integration plan for the booking process on both customer and rider interfaces of the CitiMovers application.

---

## Table of Contents

1. [Booking Flow Overview](#booking-flow-overview)
2. [Firestore Collections](#firestore-collections)
3. [Customer-Side Booking Process](#customer-side-booking-process)
4. [Rider-Side Booking Process](#rider-side-booking-process)
5. [Data Flow & Correlation](#data-flow--correlation)
6. [Service Layer Requirements](#service-layer-requirements)
7. [Screen-by-Screen Implementation](#screen-by-screen-implementation)
8. [Notification System](#notification-system)
9. [Payment Integration](#payment-integration)
10. [Testing Checklist](#testing-checklist)

---

## Booking Flow Overview

### High-Level Flow

```
Customer                      Firebase                        Rider
  |                             |                             |
  |-- Create Booking ------------>| bookings collection          |
  |                             |                             |
  |<-- Booking Created --------|                             |
  |                             |-- Notify Riders ---------->|
  |                             |                             |
  |                             |<-- Rider Accepts --------|
  |                             |                             |
  |<-- Driver Assigned --------|                             |
  |                             |                             |
  |-- Track Delivery ---------->| bookings collection          |
  |                             |                             |
  |                             |-- Update Status ---------->|
  |                             |                             |
  |<-- Delivery Complete ----|                             |
  |                             |                             |
  |-- Submit Rating/Review -->| reviews collection           |
  |                             |                             |
  |                             |-- Notify Rider ----------->|
  |                             |                             |
  |                             |<-- Mark Complete --------|
```

### Booking Status States

| Status | Description | Customer View | Rider View |
|--------|-------------|---------------|-------------|
| `pending` | Booking created, waiting for rider | Available in delivery requests |
| `accepted` | Rider accepted, driver assigned | In progress - heading to pickup |
| `arrived_at_pickup` | Driver at pickup location | At pickup - confirm loading |
| `loading` | Loading items | Loading items - take photos |
| `in_transit` | On the way to drop-off | In transit - track on map |
| `arrived_at_dropoff` | At drop-off location | At drop-off - confirm unloading |
| `unloading` | Unloading items | Unloading items - take photos |
| `completed` | Delivery complete, rate driver | Completed - view earnings |
| `cancelled` | Booking cancelled | Booking cancelled |
| `cancelled_by_rider` | Rider cancelled booking | Booking cancelled |

---

## Firestore Collections

### Existing Collections

| Collection | Purpose | Fields |
|------------|---------|---------|
| `users` | Customer user data | userId, name, phoneNumber, email, profilePhoto, createdAt |
| `riders` | Rider user data | riderId, name, phoneNumber, email, profilePhoto, vehicleType, vehiclePlateNumber, vehicleModel, vehicleColor, isOnline, currentLocation, totalEarnings, totalDeliveries, rating |
| `bookings` | Booking records | bookingId, customerId, riderId, driverId, pickupLocation, dropoffLocation, vehicle, distance, estimatedFare, actualFare, loadingDemurrage, unloadingDemurrage, bookingType, scheduledDateTime, status, paymentMethod, notes, createdAt, completedAt |
| `drivers` | Driver information | driverId, name, phoneNumber, profilePhoto, vehicleType, vehiclePlateNumber, vehicleModel, vehicleColor, rating, totalDeliveries |
| `notifications` | User notifications | notificationId, userId, type, title, message, data, isRead, createdAt |
| `saved_locations` | Customer saved locations | locationId, userId, label, address, latitude, longitude, city, province, country |
| `promo_banners` | Promo banners | bannerId, imageUrl, title, description, isActive, createdAt |
| `payment_methods` | Payment methods | methodId, userId, type, provider, lastFourDigits, isDefault |
| `wallet_transactions` | Rider wallet transactions | transactionId, riderId, type, amount, balanceBefore, balanceAfter, description, createdAt |
| `email_notifications` | Email notification logs | notificationId, to, subject, body, status, sentAt |

### New Collections Needed

| Collection | Purpose | Fields |
|------------|---------|---------|
| `delivery_requests` | Rider delivery requests | requestId, bookingId, riderId, customerId, pickupLocation, dropoffLocation, vehicle, distance, estimatedFare, status, createdAt, respondedAt |
| `reviews` | Customer reviews for riders | reviewId, bookingId, customerId, riderId, rating, review, photos, tipAmount, createdAt |
| `booking_events` | Booking event logs | eventId, bookingId, type, description, data, createdAt |

---

## Customer-Side Booking Process

### Step 1: Booking Start (BookingStartScreen)

**Purpose:** Select pickup and drop-off locations

**Input:**
- User current location (from LocationService)
- Saved locations (from SavedLocationService)

**Output:**
- `pickupLocation: LocationModel`
- `dropoffLocation: LocationModel`
- `distance: double`

**Firebase Integration:**
- ✅ MapsService (Google Maps API)
- ✅ LocationService (Geolocator)
- ✅ SavedLocationService (Firestore)

**Data Flow:**
```dart
// User selects pickup location
LocationModel pickup = await MapsService.searchPlaces(query) 
  ?? await MapsService.getPlaceDetails(placeId)
  ?? await LocationService.getCurrentLocation();

// User selects drop-off location
LocationModel dropoff = await MapsService.searchPlaces(query)
  ?? await MapsService.getPlaceDetails(placeId);

// Calculate route
RouteInfo route = await MapsService.calculateRoute(pickup, dropoff);
double distance = route.distanceKm;
int duration = route.durationMinutes;
```

---

### Step 2: Vehicle Selection (VehicleSelectionScreen)

**Purpose:** Select vehicle type for delivery

**Input:**
- `pickupLocation: LocationModel`
- `dropoffLocation: LocationModel`
- `distance: double`

**Output:**
- `vehicle: VehicleModel`

**Firebase Integration:**
- ✅ VehicleModel (static data from model)

**Data Flow:**
```dart
// Get available vehicles
List<VehicleModel> vehicles = VehicleModel.getAvailableVehicles();

// Calculate fare for each vehicle
for (VehicleModel vehicle in vehicles) {
  double fare = MapsService.calculateFare(
    distanceKm: distance,
    vehicleType: vehicle.name,
  );
}
```

---

### Step 3: Booking Summary (BookingSummaryScreen)

**Purpose:** Review booking details and confirm

**Input:**
- `pickupLocation: LocationModel`
- `dropoffLocation: LocationModel`
- `vehicle: VehicleModel`
- `distance: double`

**Output:**
- `booking: BookingModel` (created)

**Firebase Integration:**
- ❌ BookingService.createBooking() - needs proper implementation
- ❌ AuthService.currentUser - needs proper userId
- ❌ Payment processing - needs integration

**Current Issues:**
```dart
// Line 155: Hardcoded customer_id
customerId: 'customer_id_placeholder', // ❌ Should be: user.userId

// Line 160: Hardcoded distance
distance: 0.0, // ❌ Should be: widget.distance

// Line 162: Hardcoded payment method
paymentMethod: 'cash', // ❌ Should be: _selectedPaymentMethod
```

**Required Implementation:**
```dart
Future<void> _confirmBooking() async {
  final authService = AuthService();
  final user = authService.currentUser;
  
  if (user == null) {
    UIHelpers.showErrorToast('Please login to continue');
    return;
  }

  // Create booking with proper data
  final booking = await _bookingService.createBooking(
    customerId: user.userId, // ✅ Use actual user ID
    pickupLocation: widget.pickupLocation,
    dropoffLocation: widget.dropoffLocation,
    vehicle: widget.vehicle,
    bookingType: _bookingType,
    scheduledDateTime: _scheduledDateTime,
    distance: widget.distance, // ✅ Use actual distance
    estimatedFare: _estimatedFare,
    paymentMethod: _selectedPaymentMethod, // ✅ Use selected payment
    notes: _notesController.text.trim().isEmpty 
        ? null 
        : _notesController.text.trim(),
  );

  if (booking != null) {
    // Send OTP verification
    final otpSent = await authService.sendOTP(user.phoneNumber);
    
    if (otpSent) {
      // Navigate to OTP verification
      Navigator.push(..., OTPVerificationScreen(
        phoneNumber: user.phoneNumber,
        isSignup: false,
        isBookingFlow: true,
        booking: booking,
      ));
    }
  }
}
```

---

### Step 4: OTP Verification (OTPVerificationScreen)

**Purpose:** Verify customer phone number

**Input:**
- `phoneNumber: String`
- `isSignup: bool`
- `isBookingFlow: bool`
- `booking: BookingModel?`

**Output:**
- User authenticated
- Navigate to tracking screen

**Firebase Integration:**
- ✅ AuthService.sendOTP()
- ✅ AuthService.verifyOTP()

**Data Flow:**
```dart
// Verify OTP
final isValid = await _authService.verifyOTP(phoneNumber, otpCode);

if (isValid) {
  if (isBookingFlow && booking != null) {
    // Navigate to delivery tracking
    Navigator.push(..., DeliveryTrackingScreen(booking: booking!));
  } else {
    // Navigate to home
    Navigator.pushAndRemoveUntil(..., HomeScreen());
  }
}
```

---

### Step 5: Delivery Tracking (DeliveryTrackingScreen)

**Purpose:** Track delivery in real-time

**Input:**
- `booking: BookingModel`

**Output:**
- Real-time updates on delivery status
- Driver information

**Firebase Integration:**
- ✅ BookingService.getBookingStream()
- ✅ DriverService.getDriver()
- ✅ NotificationService

**Data Flow:**
```dart
// Listen to booking updates
StreamSubscription bookingStream = _bookingService
  .getBookingStream(booking.bookingId)
  .listen((updatedBooking) {
    // Update UI with new status
    setState(() {
      _booking = updatedBooking;
    });
  });

// Get driver info when assigned
if (booking.riderId != null) {
  final rider = await _riderAuthService.getRider(booking.riderId!);
  // Update UI with rider info
}
```

---

### Step 6: Delivery Completion (DeliveryCompletionScreen)

**Purpose:** Confirm delivery receipt, rate rider, add tip

**Input:**
- `booking: BookingModel`
- `loadingDemurrage: double`
- `unloadingDemurrage: double`

**Output:**
- Rating submitted
- Review submitted
- Photos uploaded
- Tip processed

**Firebase Integration:**
- ❌ Rating/review submission - needs implementation
- ❌ Photo upload - needs implementation
- ❌ Tip processing - needs implementation

**Current Issues:**
```dart
// Line 372: Hardcoded driver name
_buildSummaryRow(Icons.person, 'Driver', 'Driver Name'), // ❌

// Lines 233-234: Simulated API call
await Future.delayed(const Duration(seconds: 2)); // ❌

// Lines 252-259: Debug print only
debugPrint('Tip Amount: P${_selectedTipAmount}'); // ❌ Not saved to Firebase
```

**Required Implementation:**
```dart
Future<void> _submitReview() async {
  if (!_isConfirmed) {
    UIHelpers.showErrorToast('Please confirm delivery receipt');
    return;
  }

  if (_rating == 0) {
    UIHelpers.showErrorToast('Please provide a rating');
    return;
  }

  setState(() => _isSubmitting = true);

  // Upload photos to Firebase Storage
  List<String> photoUrls = [];
  for (XFile image in _selectedImages) {
    final url = await _storageService.uploadDeliveryPhoto(
      bookingId: widget.booking.bookingId!,
      image: File(image.path),
    );
    photoUrls.add(url);
  }

  // Submit review to Firestore
  await _bookingService.submitReview(
    bookingId: widget.booking.bookingId!,
    rating: _rating,
    review: _reviewController.text.trim(),
    photos: photoUrls,
    tipAmount: _wantsToTip ? _selectedTipAmount : 0,
    tipReasons: _selectedTipReasons,
  );

  if (mounted) {
    setState(() => _isSubmitting = false);
    UIHelpers.showSuccessToast('Thank you for your feedback!');
    
    // Navigate back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
```

**New Service Method Needed:**
```dart
// In BookingService
Future<bool> submitReview({
  required String bookingId,
  required double rating,
  String? review,
  List<String>? photos,
  double? tipAmount,
  List<String>? tipReasons,
}) async {
  try {
    // Create review document
    await _firestore.collection('reviews').add({
      'bookingId': bookingId,
      'customerId': AuthService().currentUser?.userId,
      'riderId': _getRiderIdFromBooking(bookingId),
      'rating': rating,
      'review': review,
      'photos': photos ?? [],
      'tipAmount': tipAmount ?? 0,
      'tipReasons': tipReasons ?? [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update booking status to completed
    await _firestore
      .collection('bookings')
      .doc(bookingId)
      .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

    // Send notification to rider
    await NotificationService.sendNotification(
      userId: _getRiderIdFromBooking(bookingId),
      type: 'review_received',
      title: 'New Review',
      message: 'You received a ${rating} star rating!',
      data: {'bookingId': bookingId},
    );

    return true;
  } catch (e) {
    debugPrint('Error submitting review: $e');
    return false;
  }
}
```

---

## Rider-Side Booking Process

### Step 1: Rider Home (RiderHomeTab)

**Purpose:** View available delivery requests

**Input:**
- Rider authenticated

**Output:**
- List of available delivery requests

**Firebase Integration:**
- ✅ RiderAuthService.getRider()
- ✅ RiderAuthService.getDeliveryRequestsStream()

**Data Flow:**
```dart
// Listen to delivery requests
Stream<DeliveryRequestModel> deliveryRequests = _riderAuthService
  .getDeliveryRequestsStream(riderId);

// Filter by status (pending, accepted, in_progress)
List<DeliveryRequestModel> pendingRequests = deliveryRequests
  .where((r) => r.status == 'pending')
  .toList();
```

---

### Step 2: Accept Delivery Request

**Purpose:** Rider accepts a delivery request

**Input:**
- `deliveryRequest: DeliveryRequestModel`

**Output:**
- Delivery accepted
- Booking updated with rider assignment

**Firebase Integration:**
- ❌ Accept delivery - needs implementation

**Required Implementation:**
```dart
Future<bool> acceptDeliveryRequest({
  required String requestId,
  required String riderId,
}) async {
  try {
    // Update delivery request status
    await _firestore
      .collection('delivery_requests')
      .doc(requestId)
      .update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

    // Update booking with rider assignment
    await _firestore
      .collection('bookings')
      .doc(requestId)
      .update({
        'riderId': riderId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

    // Send notification to customer
    await NotificationService.sendNotification(
      userId: _getCustomerIdFromBooking(requestId),
      type: 'driver_assigned',
      title: 'Driver Assigned',
      message: 'Your driver is on the way!',
      data: {'bookingId': requestId},
    );

    return true;
  } catch (e) {
    debugPrint('Error accepting delivery: $e');
    return false;
  }
}
```

---

### Step 3: Delivery Progress (RiderDeliveryProgressScreen)

**Purpose:** Track and update delivery progress

**Input:**
- `booking: BookingModel`

**Output:**
- Delivery status updated
- Photos uploaded for each stage
- Location updates

**Firebase Integration:**
- ❌ Status updates - needs implementation
- ❌ Photo uploads - needs implementation
- ❌ Location updates - needs implementation

**Current Issues:**
```dart
// Lines 106-109: Mock coordinates
final LatLng _currentLocation = LatLng(14.5995, 120.9842); // ❌ Mock Manila coordinates

// Lines 329-338: Mock email sending
_sendCompletionEmails() {
  // Mock email sending - not implemented
} // ❌
```

**Required Implementation:**
```dart
// Update delivery status
Future<void> _updateDeliveryStatus(String status) async {
  await _bookingService.updateBookingStatus(
    bookingId: widget.booking.bookingId!,
    status: status,
  );

  // Send notification to customer
  await NotificationService.sendNotification(
    userId: widget.booking.customerId,
    type: 'delivery_status_update',
    title: _getStatusTitle(status),
    message: _getStatusMessage(status),
    data: {'bookingId': widget.booking.bookingId},
  );
}

// Upload photo for delivery stage
Future<void> _uploadStagePhoto(String stage, XFile photo) async {
  final url = await _storageService.uploadDeliveryPhoto(
    bookingId: widget.booking.bookingId!,
    stage: stage, // 'loading_start', 'loading_finish', etc.
    image: File(photo.path),
  );

  // Update booking with photo URL
  await _bookingService.addDeliveryPhoto(
    bookingId: widget.booking.bookingId!,
    stage: stage,
    photoUrl: url,
  );
}

// Update rider location
Future<void> _updateLocation() async {
  final location = await _locationService.getCurrentLocation();
  
  await _riderAuthService.updateLocation(
    riderId: _riderAuthService.currentRider?.riderId,
    latitude: location.latitude,
    longitude: location.longitude,
  );
}
```

---

### Step 4: Delivery History (RiderDeliveryHistoryScreen)

**Purpose:** View past deliveries

**Input:**
- Rider authenticated

**Output:**
- List of completed deliveries

**Firebase Integration:**
- ✅ RiderAuthService.getDeliveriesStream()

**Data Flow:**
```dart
// Get rider's deliveries
Stream<List<BookingModel>> deliveries = _riderAuthService
  .getDeliveriesStream(riderId);

// Filter by status
List<BookingModel> completedDeliveries = deliveries
  .where((b) => b.status == 'completed')
  .toList();
```

---

## Data Flow & Correlation

### Customer to Rider Data Flow

```
Customer Action                    Firebase Update                    Rider Action
----------------                 -----------------                   -------------
Create Booking              -> bookings.add({status: 'pending'})   -> Show in delivery requests
                           -> delivery_requests.add()            -> Accept delivery
                           -> notifications.add(to rider)        -> Receive notification

Rider Accepts               -> bookings.update({riderId, status: 'accepted'}) -> Show driver assigned
                           -> notifications.add(to customer)     -> Receive notification

Rider Updates Status        -> bookings.update({status})          -> Update status display
                           -> notifications.add(to customer)     -> Receive notification

Customer Completes          -> bookings.update({status: 'completed'}) -> Update earnings
                           -> reviews.add({rating, tip})       -> Show rating
                           -> notifications.add(to rider)        -> Receive notification
```

### Real-time Synchronization

| Event | Customer Update | Rider Update |
|--------|----------------|--------------|
| Booking created | - | New delivery request appears |
| Rider accepted | Driver assigned notification | Request removed from list |
| Status changed | Status update notification | Status updated |
| Delivery complete | Rating prompt | Earnings updated, rating shown |

---

## Service Layer Requirements

### BookingService - New Methods Needed

```dart
class BookingService {
  // Existing
  Future<BookingModel?> createBooking({...}) async {...}
  Stream<BookingModel?> getBookingStream(String bookingId) {...}
  
  // NEW: Submit review
  Future<bool> submitReview({
    required String bookingId,
    required double rating,
    String? review,
    List<String>? photos,
    double? tipAmount,
    List<String>? tipReasons,
  }) async {...}
  
  // NEW: Update booking status
  Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {...}
  
  // NEW: Add delivery photo
  Future<bool> addDeliveryPhoto({
    required String bookingId,
    required String stage,
    required String photoUrl,
  }) async {...}
  
  // NEW: Get delivery photos
  Future<List<Map<String, dynamic>>> getDeliveryPhotos(String bookingId) async {...}
  
  // NEW: Accept delivery request (for riders)
  Future<bool> acceptDeliveryRequest({
    required String requestId,
    required String riderId,
  }) async {...}
  
  // NEW: Reject delivery request (for riders)
  Future<bool> rejectDeliveryRequest({
    required String requestId,
    required String riderId,
  }) async {...}
}
```

### RiderAuthService - New Methods Needed

```dart
class RiderAuthService {
  // Existing
  Future<RiderModel?> getRider(String riderId) async {...}
  Stream<DeliveryRequestModel?> getDeliveryRequestsStream(String riderId) {...}
  
  // NEW: Accept delivery request
  Future<bool> acceptDeliveryRequest(String requestId) async {...}
  
  // NEW: Reject delivery request
  Future<bool> rejectDeliveryRequest(String requestId) async {...}
  
  // NEW: Update rider location
  Future<bool> updateLocation({
    required String riderId,
    required double latitude,
    required double longitude,
  }) async {...}
  
  // NEW: Get delivery requests
  Future<List<DeliveryRequestModel>> getDeliveryRequests(String riderId) async {...}
}
```

### StorageService - New Methods Needed

```dart
class StorageService {
  // NEW: Upload delivery photo
  Future<String> uploadDeliveryPhoto({
    required String bookingId,
    required File image,
    String? stage, // 'loading_start', 'loading_finish', etc.
  }) async {
    try {
      final path = 'bookings/$bookingId/photos/${stage ?? 'general'}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(image);
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading delivery photo: $e');
      rethrow;
    }
  }
  
  // NEW: Get delivery photos
  Future<List<String>> getDeliveryPhotos(String bookingId) async {
    try {
      final result = await _storage.ref('bookings/$bookingId/photos').listAll();
      final urls = await Future.wait(
        result.items.map((ref) => ref.getDownloadURL()),
      );
      return urls;
    } catch (e) {
      debugPrint('Error getting delivery photos: $e');
      return [];
    }
  }
}
```

---

## Screen-by-Screen Implementation

### Customer Side - Booking Flow Screens

| Screen | File Path | Purpose | Status | Required Changes |
|--------|-----------|---------|--------|-----------------|
| **BookingStartScreen** | [`lib/screens/booking/booking_start_screen.dart`](lib/screens/booking/booking_start_screen.dart) | Select pickup/dropoff locations | ✅ Done | None |
| **LocationPickerScreen** | [`lib/screens/booking/location_picker_screen.dart`](lib/screens/booking/location_picker_screen.dart) | Search/select locations | ✅ Done | None |
| **MapViewScreen** | [`lib/screens/booking/map_view_screen.dart`](lib/screens/booking/map_view_screen.dart) | View map, select locations | ✅ Done | None |
| **SavedLocationsScreen** | [`lib/screens/booking/saved_locations_screen.dart`](lib/screens/booking/saved_locations_screen.dart) | Manage saved locations | ✅ Done | None |
| **VehicleSelectionScreen** | [`lib/screens/booking/vehicle_selection_screen.dart`](lib/screens/booking/vehicle_selection_screen.dart) | Select vehicle type | ✅ Done | None |
| **BookingSummaryScreen** | [`lib/screens/booking/booking_summary_screen.dart`](lib/screens/booking/booking_summary_screen.dart) | Review & confirm booking | ⚠️ Partial | Fix hardcoded customer_id (line 155), distance (line 160), paymentMethod (line 162) |
| **OTPVerificationScreen** | [`lib/screens/auth/otp_verification_screen.dart`](lib/screens/auth/otp_verification_screen.dart) | Verify phone number | ✅ Done | None |
| **DeliveryTrackingScreen** | [`lib/screens/delivery/delivery_tracking_screen.dart`](lib/screens/delivery/delivery_tracking_screen.dart) | Track delivery in real-time | ✅ Done | None |
| **DriverCredentialsScreen** | [`lib/screens/delivery/driver_credentials_screen.dart`](lib/screens/delivery/driver_credentials_screen.dart) | View driver credentials | ✅ Done | None |
| **DriverInfoScreen** | [`lib/screens/delivery/driver_info_screen.dart`](lib/screens/delivery/driver_info_screen.dart) | View driver info | ✅ Done | None |
| **DeliveryCompletionScreen** | [`lib/screens/delivery/delivery_completion_screen.dart`](lib/screens/delivery/delivery_completion_screen.dart) | Confirm delivery, rate rider | ⚠️ Partial | Fix hardcoded driver name (line 372), implement review submission (lines 233-264), photo upload, tip processing |

### Customer Side - Non-Booking Screens

| Screen | File Path | Purpose | Status | Required Changes |
|--------|-----------|---------|--------|-----------------|
| **HomeTab** | [`lib/screens/tabs/home_tab.dart`](lib/screens/tabs/home_tab.dart) | Main dashboard | ✅ Done | None |
| **BookingsTab** | [`lib/screens/tabs/bookings_tab.dart`](lib/screens/tabs/bookings_tab.dart) | View bookings | ✅ Done | None |
| **NotificationsTab** | [`lib/screens/tabs/notifications_tab.dart`](lib/screens/tabs/notifications_tab.dart) | View notifications | ✅ Done | None |
| **ProfileTab** | [`lib/screens/tabs/home_tab.dart`](lib/screens/tabs/home_tab.dart) | View profile | ✅ Done | None |
| **WelcomeScreen** | [`lib/screens/auth/welcome_screen.dart`](lib/screens/auth/welcome_screen.dart) | Welcome screen | ✅ Done | None |
| **LoginScreen** | [`lib/screens/auth/login_screen.dart`](lib/screens/auth/login_screen.dart) | Login | ✅ Done | None |
| **SignupScreen** | [`lib/screens/auth/signup_screen.dart`](lib/screens/auth/signup_screen.dart) | Signup | ✅ Done | None |
| **EmailVerificationScreen** | [`lib/screens/auth/email_verification_screen.dart`](lib/screens/auth/email_verification_screen.dart) | Email verification | ✅ Done | None |
| **EditProfileScreen** | [`lib/screens/profile/edit_profile_screen.dart`](lib/screens/profile/edit_profile_screen.dart) | Edit profile | ✅ Done | None |
| **ChangePasswordScreen** | [`lib/screens/profile/change_password_screen.dart`](lib/screens/profile/change_password_screen.dart) | Change password | ✅ Done | None |
| **ProfileScreen** | [`lib/screens/profile/profile_screen.dart`](lib/screens/profile/profile_screen.dart) | View profile | ✅ Done | None |
| **OnboardingScreen** | [`lib/screens/onboarding_screen.dart`](lib/screens/onboarding_screen.dart) | App onboarding | ✅ Done | Static content (intentional) |
| **WhyChooseUsScreen** | [`lib/screens/why_choose_us_screen.dart`](lib/screens/why_choose_us_screen.dart) | Feature info | ✅ Done | Static content (intentional) |
| **HelpCenterScreen** | [`lib/screens/help_center_screen.dart`](lib/screens/help_center_screen.dart) | Help center | ✅ Done | Static contact info (intentional) |
| **PrivacyPolicyScreen** | [`lib/screens/privacy_policy_screen.dart`](lib/screens/privacy_policy_screen.dart) | Privacy policy | ✅ Done | Static content (intentional) |
| **TermsConditionsScreen** | [`lib/screens/terms_conditions_screen.dart`](lib/screens/terms_conditions_screen.dart) | Terms & conditions | ✅ Done | Static content (intentional) |

### Rider Side - Booking Flow Screens

| Screen | File Path | Purpose | Status | Required Changes |
|--------|-----------|---------|--------|-----------------|
| **RiderHomeTab** | [`lib/rider/screens/tabs/rider_home_tab.dart`](lib/rider/screens/tabs/rider_home_tab.dart) | View delivery requests | ✅ Done | None |
| **RiderDeliveriesTab** | [`lib/rider/screens/tabs/rider_deliveries_tab.dart`](lib/rider/screens/tabs/rider_deliveries_tab.dart) | View deliveries | ✅ Done | None |
| **RiderEarningsTab** | [`lib/rider/screens/tabs/rider_earnings_tab.dart`](lib/rider/screens/tabs/rider_earnings_tab.dart) | View earnings | ✅ Done | None |
| **RiderProfileTab** | [`lib/rider/screens/tabs/rider_profile_tab.dart`](lib/rider/screens/tabs/rider_profile_tab.dart) | View profile | ✅ Done | None |
| **RiderNotificationsTab** | [`lib/rider/screens/tabs/rider_notifications_tab.dart`](lib/rider/screens/tabs/rider_notifications_tab.dart) | View notifications | ✅ Done | None |
| **RiderDeliveryProgressScreen** | [`lib/rider/screens/delivery/rider_delivery_progress_screen.dart`](lib/rider/screens/delivery/rider_delivery_progress_screen.dart) | Track delivery progress | ⚠️ Partial | Fix mock coordinates (lines 86, 472-474), implement status updates, photo uploads, location updates, email notifications |
| **RiderDeliveryHistoryScreen** | [`lib/rider/screens/profile/rider_delivery_history_screen.dart`](lib/rider/screens/profile/rider_delivery_history_screen.dart) | View delivery history | ✅ Done | None |

### Rider Side - Non-Booking Screens

| Screen | File Path | Purpose | Status | Required Changes |
|--------|-----------|---------|--------|-----------------|
| **RiderHomeScreen** | [`lib/rider/screens/rider_home_screen.dart`](lib/rider/screens/rider_home_screen.dart) | Rider dashboard | ✅ Done | None |
| **RiderNotificationsScreen** | [`lib/rider/screens/rider_notifications_screen.dart`](lib/rider/screens/rider_notifications_screen.dart) | View notifications | ✅ Done | None |
| **RiderLoginScreen** | [`lib/rider/screens/auth/rider_login_screen.dart`](lib/rider/screens/auth/rider_login_screen.dart) | Rider login | ✅ Done | None |
| **RiderSignupScreen** | [`lib/rider/screens/auth/rider_signup_screen.dart`](lib/rider/screens/auth/rider_signup_screen.dart) | Rider signup | ✅ Done | None |
| **RiderOTPVerificationScreen** | [`lib/rider/screens/auth/rider_otp_verification_screen.dart`](lib/rider/screens/auth/rider_otp_verification_screen.dart) | OTP verification | ✅ Done | None |
| **RiderOnboardingScreen** | [`lib/rider/screens/auth/rider_onboarding_screen.dart`](lib/rider/screens/auth/rider_onboarding_screen.dart) | Rider onboarding | ✅ Done | None |
| **RiderSplashScreen** | [`lib/rider/screens/auth/rider_splash_screen.dart`](lib/rider/screens/auth/rider_splash_screen.dart) | Rider splash | ✅ Done | None |
| **RiderEditProfileScreen** | [`lib/rider/screens/profile/rider_edit_profile_screen.dart`](lib/rider/screens/profile/rider_edit_profile_screen.dart) | Edit profile | ✅ Done | None |
| **RiderVehicleDetailsScreen** | [`lib/rider/screens/profile/rider_vehicle_details_screen.dart`](lib/rider/screens/profile/rider_vehicle_details_screen.dart) | Vehicle details | ✅ Done | None |
| **RiderDocumentsScreen** | [`lib/rider/screens/profile/rider_documents_screen.dart`](lib/rider/screens/profile/rider_documents_screen.dart) | Documents | ✅ Done | None |
| **RiderPaymentMethodsScreen** | [`lib/rider/screens/profile/rider_payment_methods_screen.dart`](lib/rider/screens/profile/rider_payment_methods_screen.dart) | Payment methods | ✅ Done | None |
| **RiderSettingsScreen** | [`lib/rider/screens/profile/rider_settings_screen.dart`](lib/rider/screens/profile/rider_settings_screen.dart) | Settings | ✅ Done | None |
| **HelpCenterScreen** | [`lib/screens/help_center_screen.dart`](lib/screens/help_center_screen.dart) | Help center | ✅ Done | Static contact info (intentional) |
| **PrivacyPolicyScreen** | [`lib/screens/privacy_policy_screen.dart`](lib/screens/privacy_policy_screen.dart) | Privacy policy | ✅ Done | Static content (intentional) |
| **TermsConditionsScreen** | [`lib/screens/terms_conditions_screen.dart`](lib/screens/terms_conditions_screen.dart) | Terms & conditions | ✅ Done | Static content (intentional) |
| **WhyChooseUsScreen** | [`lib/screens/why_choose_us_screen.dart`](lib/screens/why_choose_us_screen.dart) | Feature info | ✅ Done | Static content (intentional) |
| **OnboardingScreen** | [`lib/screens/onboarding_screen.dart`](lib/screens/onboarding_screen.dart) | App onboarding | ✅ Done | Static content (intentional) |

---

## Notification System

### Notification Types

| Type | Trigger | Recipient | Message |
|------|---------|------------|---------|
| `booking_created` | Customer creates booking | Rider | New delivery request |
| `driver_assigned` | Rider accepts booking | Customer | Driver assigned |
| `status_update` | Status changes | Both | Delivery status updated |
| `arrived_at_pickup` | Rider arrives | Customer | Driver at pickup |
| `loading_complete` | Loading done | Customer | Items loaded |
| `in_transit` | On the way | Customer | Driver en route |
| `arrived_at_dropoff` | At destination | Customer | Driver arrived |
| `delivery_complete` | Delivery done | Both | Delivery completed |
| `review_received` | Customer rates rider | Rider | New review |
| `tip_received` | Customer tips rider | Rider | You received a tip |

### Notification Implementation

```dart
class NotificationService {
  static Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Get user notifications stream
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList());
  }
}
```

---

## Payment Integration

### Payment Flow

```
Customer                    Payment Gateway                Firebase
  |                             |                           |
  |-- Select Payment -------->|                           |
  |                             |-- Process Payment -------->|
  |                             |                           |
  |<-- Payment Success -------|                           |
  |                             |                           |
  |-- Confirm Booking -------->| bookings.update({status: 'paid'}) |
  |                             |                           |
  |                             |-- Notify Rider ---------->|
```

### Payment Methods

| Method | Provider | Status |
|--------|-----------|--------|
| GCash | GCash API | ⚠️ Needs integration |
| Maya | Maya API | ⚠️ Needs integration |
| Debit Card | Payment gateway | ⚠️ Needs integration |
| Credit Card | Payment gateway | ⚠️ Needs integration |

### PaymentService Enhancement

```dart
class PaymentService {
  // NEW: Process payment
  Future<PaymentResult> processPayment({
    required String bookingId,
    required double amount,
    required String method,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      switch (method) {
        case 'Gcash':
          return await _processGCashPayment(amount, metadata);
        case 'Maya':
          return await _processMayaPayment(amount, metadata);
        case 'Debit Card':
        case 'Credit Card':
          return await _processCardPayment(amount, metadata);
        default:
          return PaymentResult(success: false, message: 'Invalid payment method');
      }
    } catch (e) {
      return PaymentResult(success: false, message: e.toString());
    }
  }
  
  // NEW: Process GCash payment
  Future<PaymentResult> _processGCashPayment(
    double amount,
    Map<String, dynamic>? metadata,
  ) async {
    // Implement GCash API integration
    // Return payment result
  }
  
  // NEW: Process Maya payment
  Future<PaymentResult> _processMayaPayment(
    double amount,
    Map<String, dynamic>? metadata,
  ) async {
    // Implement Maya API integration
    // Return payment result
  }
  
  // NEW: Process card payment
  Future<PaymentResult> _processCardPayment(
    double amount,
    Map<String, dynamic>? metadata,
  ) async {
    // Implement payment gateway integration
    // Return payment result
  }
}
```

---

## Testing Checklist

### Customer Side

- [ ] Create booking with valid locations
- [ ] Select vehicle type
- [ ] View booking summary with correct data
- [ ] Complete payment
- [ ] Verify OTP
- [ ] Track delivery in real-time
- [ ] View driver information
- [ ] Confirm delivery receipt
- [ ] Submit rating and review
- [ ] Upload delivery photos
- [ ] Add tip to rider
- [ ] View booking history

### Rider Side

- [ ] View available delivery requests
- [ ] Accept delivery request
- [ ] Update location in real-time
- [ ] Update delivery status
- [ ] Upload loading photos
- [ ] Upload unloading photos
- [ ] Complete delivery
- [ ] View earnings
- [ ] View delivery history
- [ ] View received ratings
- [ ] View received tips

### Integration Tests

- [ ] Customer creates booking → Rider receives notification
- [ ] Rider accepts booking → Customer receives notification
- [ ] Rider updates status → Customer sees update
- [ ] Customer completes delivery → Rider sees completion
- [ ] Customer submits rating → Rider sees rating
- [ ] Payment processed → Booking status updated
- [ ] Location updates → Map reflects position

---

## Implementation Priority

### Phase 1: Core Booking Flow (High Priority)
1. Fix BookingSummaryScreen hardcoded values
2. Implement BookingService.submitReview()
3. Implement BookingService.updateBookingStatus()
4. Implement RiderAuthService.acceptDeliveryRequest()
5. Implement RiderAuthService.updateLocation()
6. Implement StorageService.uploadDeliveryPhoto()

### Phase 2: Delivery Progress (Medium Priority)
1. Fix RiderDeliveryProgressScreen mock coordinates
2. Implement status update flow
3. Implement photo upload flow
4. Implement location tracking

### Phase 3: Completion Flow (Medium Priority)
1. Fix DeliveryCompletionScreen hardcoded driver name
2. Implement review submission
3. Implement tip processing
4. Implement notification system

### Phase 4: Payment Integration (Low Priority)
1. Implement GCash integration
2. Implement Maya integration
3. Implement card payment integration

---

## Firestore Security Rules

### Bookings Collection

```javascript
match /bookings/{bookingId} {
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.customerId ||
    request.auth.uid == resource.data.riderId
  );
  allow create: if request.auth != null && 
    request.auth.uid == request.data.customerId;
  allow update: if request.auth != null && (
    request.auth.uid == resource.data.customerId ||
    request.auth.uid == resource.data.riderId
  );
}
```

### Reviews Collection

```javascript
match /reviews/{reviewId} {
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.customerId ||
    request.auth.uid == resource.data.riderId
  );
  allow create: if request.auth != null && 
    request.auth.uid == request.data.customerId;
}
```

---

## Summary

This integration plan provides a comprehensive roadmap for implementing the booking process for both customers and riders. The key areas requiring implementation are:

1. **BookingSummaryScreen** - Fix hardcoded values
2. **DeliveryCompletionScreen** - Implement review/tip submission
3. **RiderDeliveryProgressScreen** - Implement status updates and photo uploads
4. **BookingService** - Add review submission and status update methods
5. **RiderAuthService** - Add delivery request methods
6. **StorageService** - Add delivery photo upload methods
7. **NotificationService** - Ensure proper notification flow
8. **PaymentService** - Implement payment gateway integration

All other features (auth, profile, tabs, notifications, settings) are already fully integrated with Firebase.
