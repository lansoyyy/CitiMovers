# CitiMovers - Customer App Development Plan

## Project Overview
**CitiMovers** is a multi-platform ride-hailing and delivery application similar to Lalamove. This document tracks the development progress of the **Customer App** for Android and iOS.

**Brand Colors:** Red (#E53935) & Blue (#1E88E5)  
**Font Family:** Urbanist (Regular, Medium, Bold)

---

## Customer App Features

### 1. User Registration and Authentication
- Sign up with email/phone number
- Login with email/password
- Social authentication (Google, Facebook)
- Phone number verification (OTP)
- Password reset functionality
- Profile setup and management

### 2. Location Services
- Set pickup location (current location or manual selection)
- Set drop-off location (search or map selection)
- Save favorite locations (Home, Work, etc.)
- Recent locations history
- Google Maps integration for address autocomplete

### 3. Vehicle Selection
- **Wing Van** - For large cargo
- **Trailer** - For heavy-duty transport
- **6-Wheeler** - For medium to large items
- **4-Wheeler** - For standard deliveries
- **AUV** - For smaller packages
- Display vehicle capacity and specifications
- Show vehicle availability in real-time

### 4. Rate Calculation & Booking
- Automatic distance calculation using Google Maps API
- Dynamic pricing based on:
  - Distance between pickup and drop-off
  - Selected vehicle type
  - Time of day (peak hours)
  - Additional services (helpers, insurance)
- Real-time cost estimation before booking
- Booking confirmation with cost breakdown
- Add delivery notes and special instructions

### 5. Payment System
- Secure payment capture upon booking
- Payment methods:
  - Credit/Debit card
  - Digital wallets (GCash, PayMaya)
  - Cash on delivery
- Wallet system for deposits
- Transaction history and receipts
- Refund processing for cancelled bookings

### 6. Live Tracking
- Real-time driver location tracking
- Estimated time of arrival (ETA)
- Route visualization on map
- Driver details (name, photo, vehicle info, rating)
- In-app messaging with driver
- Call driver directly

### 7. Notifications
- Push notifications for:
  - Booking confirmation
  - Driver assigned
  - Driver arriving at pickup
  - Pickup completed
  - Delivery in progress
  - Delivery completed
  - Payment processed
- In-app notification center
- SMS notifications for critical updates

---

## Development Phases

### Phase 1: Foundation & Authentication ✅
**Status:** COMPLETED  
**Duration:** Day 1

#### Completed Tasks
- ✅ Project structure setup (screens, utils, widgets, services)
- ✅ Theme configuration with red/blue branding
- ✅ Custom Urbanist fonts integration
- ✅ Splash screen with animations
- ✅ Home screen UI with bottom navigation
- ✅ UI helpers (toast, snackbar, loading indicators)
- ✅ Constants and color palette setup
- ✅ API key configuration

#### Files Created
- `lib/utils/app_colors.dart` - Color palette
- `lib/utils/app_constants.dart` - App constants and API keys
- `lib/utils/app_theme.dart` - Theme configuration
- `lib/utils/ui_helpers.dart` - UI utility functions
- `lib/screens/splash_screen.dart` - Animated splash screen
- `lib/screens/home_screen.dart` - Main home interface
- `lib/main.dart` - App entry point

---

### Phase 2: Authentication System ✅
**Status:** COMPLETED  
**Duration:** Day 2

#### Completed Tasks
- ✅ User model and data structure
- ✅ Authentication service layer (mock implementation)
- ✅ Welcome screen with branding
- ✅ Sign up screen UI (mobile number focused)
- ✅ Login screen UI (mobile number focused)
- ✅ Phone verification (OTP) screen with 6-digit input
- ✅ Session management
- ✅ Form validation
- ✅ OTP resend functionality with timer
- ✅ Auto-navigation based on auth status
- ✅ Social login UI (Google placeholder)

#### Files Created
- `lib/models/user_model.dart` - User data model with Firestore mapping
- `lib/services/auth_service.dart` - Authentication service (ready for Firebase)
- `lib/screens/auth/welcome_screen.dart` - Landing screen with login/signup options
- `lib/screens/auth/login_screen.dart` - Mobile number login with OTP
- `lib/screens/auth/signup_screen.dart` - Registration with name, phone, email
- `lib/screens/auth/otp_verification_screen.dart` - 6-digit OTP verification

#### Notes
- Mobile number focused authentication (Philippines +63 format)
- OTP verification with 60-second resend timer
- Terms and conditions checkbox on signup
- Ready for Firebase Authentication integration
- Splash screen now checks auth status and routes accordingly

---

### Phase 3: Location & Maps Integration 🔄
**Status:** PENDING  
**Estimated Duration:** 3-4 days

#### Tasks
- [ ] Google Maps integration
- [ ] Current location detection
- [ ] Pickup location selection screen
- [ ] Drop-off location selection screen
- [ ] Address search with autocomplete
- [ ] Map marker customization
- [ ] Save favorite locations
- [ ] Recent locations list
- [ ] Distance calculation service
- [ ] Route drawing on map

#### Required Packages
- `google_maps_flutter`
- `geolocator`
- `geocoding`
- `google_places_flutter`
- `flutter_polyline_points`

#### Files to Create
- `lib/screens/booking/location_picker_screen.dart`
- `lib/screens/booking/map_view_screen.dart`
- `lib/services/location_service.dart`
- `lib/services/maps_service.dart`
- `lib/models/location_model.dart`
- `lib/widgets/map_widgets.dart`

---

### Phase 4: Vehicle Selection & Rate Calculation 🔄
**Status:** PENDING  
**Estimated Duration:** 2-3 days

#### Tasks
- [ ] Vehicle types configuration
- [ ] Vehicle selection screen UI
- [ ] Vehicle card widgets
- [ ] Rate calculation algorithm
- [ ] Distance-based pricing
- [ ] Vehicle-specific pricing
- [ ] Peak hour pricing logic
- [ ] Cost estimation display
- [ ] Booking summary screen
- [ ] Additional services selection

#### Files to Create
- `lib/screens/booking/vehicle_selection_screen.dart`
- `lib/screens/booking/booking_summary_screen.dart`
- `lib/services/pricing_service.dart`
- `lib/models/vehicle_model.dart`
- `lib/models/booking_model.dart`
- `lib/widgets/vehicle_card.dart`

---

### Phase 5: Payment Integration 🔄
**Status:** PENDING  
**Estimated Duration:** 3-4 days

#### Tasks
- [ ] Payment gateway integration
- [ ] Payment method selection screen
- [ ] Card payment UI
- [ ] Digital wallet integration (GCash, PayMaya)
- [ ] Wallet system implementation
- [ ] Deposit to wallet feature
- [ ] Transaction history screen
- [ ] Receipt generation
- [ ] Refund processing
- [ ] Payment security measures

#### Required Packages
- `flutter_stripe` or `paymongo_sdk`
- `cloud_firestore` (for transaction records)

#### Files to Create
- `lib/screens/payment/payment_method_screen.dart`
- `lib/screens/payment/wallet_screen.dart`
- `lib/screens/payment/transaction_history_screen.dart`
- `lib/services/payment_service.dart`
- `lib/models/payment_model.dart`
- `lib/models/transaction_model.dart`

---

### Phase 6: Live Tracking & Driver Interaction 🔄
**Status:** PENDING  
**Estimated Duration:** 3-4 days

#### Tasks
- [ ] Real-time database setup (Firestore)
- [ ] Live tracking screen UI
- [ ] Driver location updates
- [ ] Route visualization
- [ ] ETA calculation
- [ ] Driver profile display
- [ ] In-app messaging
- [ ] Call driver functionality
- [ ] Delivery status updates
- [ ] Rating and review system

#### Required Packages
- `cloud_firestore`
- `firebase_database` (for real-time updates)
- `url_launcher` (for calling)
- `flutter_chat_ui` (optional)

#### Files to Create
- `lib/screens/tracking/live_tracking_screen.dart`
- `lib/screens/tracking/driver_profile_screen.dart`
- `lib/screens/tracking/chat_screen.dart`
- `lib/screens/tracking/rating_screen.dart`
- `lib/services/tracking_service.dart`
- `lib/models/driver_model.dart`

---

### Phase 7: Push Notifications 🔄
**Status:** PENDING  
**Estimated Duration:** 2 days

#### Tasks
- [ ] Firebase Cloud Messaging setup
- [ ] Notification service implementation
- [ ] Local notification handling
- [ ] Push notification handling
- [ ] Notification center UI
- [ ] Notification preferences
- [ ] SMS integration (optional)

#### Required Packages
- `firebase_messaging`
- `flutter_local_notifications`

#### Files to Create
- `lib/services/notification_service.dart`
- `lib/screens/notifications/notification_center_screen.dart`

---

### Phase 8: Profile & Settings 🔄
**Status:** PENDING  
**Estimated Duration:** 2 days

#### Tasks
- [ ] User profile screen
- [ ] Edit profile functionality
- [ ] Settings screen
- [ ] Notification preferences
- [ ] Language selection
- [ ] Theme toggle (light/dark)
- [ ] Help & support
- [ ] Terms & conditions
- [ ] Privacy policy
- [ ] Logout functionality

#### Files to Create
- `lib/screens/profile/profile_screen.dart`
- `lib/screens/profile/edit_profile_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/help_screen.dart`

---

### Phase 9: Testing & Polish 🔄
**Status:** PENDING  
**Estimated Duration:** 3-4 days

#### Tasks
- [ ] Unit tests for services
- [ ] Widget tests for screens
- [ ] Integration tests
- [ ] Error handling improvements
- [ ] Loading states optimization
- [ ] UI/UX refinements
- [ ] Performance optimization
- [ ] Accessibility improvements
- [ ] Bug fixes

---

### Phase 10: Deployment 🔄
**Status:** PENDING  
**Estimated Duration:** 2-3 days

#### Tasks
- [ ] App icon and splash screen finalization
- [ ] Android build configuration
- [ ] iOS build configuration
- [ ] Play Store listing preparation
- [ ] App Store listing preparation
- [ ] Beta testing (TestFlight, Play Console)
- [ ] Production release

---

## Technical Stack

### Frontend
- **Framework:** Flutter 3.6+
- **Language:** Dart
- **State Management:** Provider / Riverpod (TBD)
- **Architecture:** Clean Architecture / MVVM

### Backend & Services
- **Authentication:** Firebase Auth
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage
- **Maps:** Google Maps API
- **Payment:** Stripe / PayMongo
- **Notifications:** Firebase Cloud Messaging
- **Analytics:** Firebase Analytics

### Key Packages
```yaml
dependencies:
  flutter_spinkit: ^5.2.0
  fluttertoast: ^8.2.4
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
  google_maps_flutter: ^latest
  geolocator: ^latest
  geocoding: ^latest
  firebase_messaging: ^latest
  flutter_local_notifications: ^latest
  intl: ^0.20.2
```

---

## Database Structure (Firestore)

### Collections

#### users
```
{
  userId: string
  name: string
  email: string
  phone: string
  photoUrl: string
  userType: "customer"
  walletBalance: number
  favoriteLocations: array
  createdAt: timestamp
  updatedAt: timestamp
}
```

#### bookings
```
{
  bookingId: string
  customerId: string
  driverId: string (nullable)
  pickupLocation: geopoint
  dropoffLocation: geopoint
  pickupAddress: string
  dropoffAddress: string
  vehicleType: string
  distance: number
  estimatedCost: number
  finalCost: number
  status: string (pending/accepted/in_progress/completed/cancelled)
  notes: string
  createdAt: timestamp
  updatedAt: timestamp
}
```

#### transactions
```
{
  transactionId: string
  userId: string
  bookingId: string (nullable)
  type: string (booking/deposit/refund)
  amount: number
  paymentMethod: string
  status: string
  createdAt: timestamp
}
```

---

## API Integrations

### Google Maps API
- **Maps SDK:** For map display
- **Places API:** For address autocomplete
- **Directions API:** For route calculation
- **Distance Matrix API:** For distance/duration calculation
- **Geocoding API:** For address conversion

### Payment Gateway
- **Stripe / PayMongo:** For card payments
- **GCash / PayMaya SDK:** For e-wallet payments

---

## Design Guidelines

### Colors
- **Primary Red:** #E53935
- **Primary Blue:** #1E88E5
- **Success:** #4CAF50
- **Warning:** #FFC107
- **Error:** #F44336

### Typography
- **Headings:** Bold (Urbanist-Bold)
- **Subheadings:** Medium (Urbanist-Medium)
- **Body:** Regular (Urbanist-Regular)

### Spacing
- Small: 8px
- Medium: 16px
- Large: 24px
- XLarge: 32px

---

## Development Notes

### Current Progress
- Foundation complete with splash screen, home UI, and theme setup
- Authentication system complete with mobile number focused login/signup
- OTP verification flow implemented
- Ready for Firebase integration

### Next Steps
1. Integrate Firebase Authentication for real OTP
2. Implement location services and Google Maps
3. Create booking flow with vehicle selection

### Known Issues
- None at the moment

---

## Change Log

### Day 1 - Oct 15, 2025
**Foundation Setup**
- Created project structure (screens, utils, widgets, services folders)
- Implemented theme system with red/blue branding
- Integrated Urbanist custom fonts (Regular, Medium, Bold)
- Built animated splash screen with gradient and loading indicators
- Created home screen with bottom navigation
- Added UI helper utilities for toast, snackbar, and loading states
- Configured app constants and API keys
- Set up portrait-only orientation

**Files Added:**
- `lib/utils/app_colors.dart`
- `lib/utils/app_constants.dart`
- `lib/utils/app_theme.dart`
- `lib/utils/ui_helpers.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/home_screen.dart`

### Day 2 - Oct 16, 2025
**Authentication System**
- Created user model with Firestore mapping (toMap/fromMap methods)
- Built authentication service with mock implementation
- Designed welcome screen with gradient branding
- Implemented mobile number focused login screen
- Built signup screen with name, phone, and optional email
- Created OTP verification screen with 6-digit input fields
- Added OTP resend functionality with 60-second countdown timer
- Implemented auto-navigation based on authentication status
- Added form validation for all input fields
- Integrated Philippine phone number format (+63)
- Added terms and conditions checkbox
- Created social login UI placeholders (Google)

**Files Added:**
- `lib/models/user_model.dart`
- `lib/services/auth_service.dart`
- `lib/screens/auth/welcome_screen.dart`
- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/signup_screen.dart`
- `lib/screens/auth/otp_verification_screen.dart`

**Files Modified:**
- `lib/screens/splash_screen.dart` - Added auth status check and routing

**UI Redesign (Professional Update):**
- Redesigned splash screen with clean white background (removed gradient)
- Changed logo from circle to rounded square with red background
- Updated typography for better readability
- Redesigned welcome screen with solid colors (removed gradient)
- Updated button styles for more professional appearance
- Improved spacing and layout consistency

**Files Modified:**
- `lib/screens/splash_screen.dart` - Professional redesign without gradients
- `lib/screens/auth/welcome_screen.dart` - Clean solid color design
- `lib/screens/auth/login_screen.dart` - Navigation improvements
- `lib/screens/auth/signup_screen.dart` - Navigation improvements

---

*Last Updated: Oct 16, 2025*
