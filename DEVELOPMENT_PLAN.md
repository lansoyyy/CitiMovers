# CitiMovers - Customer App Development Plan

## Project Overview
**CitiMovers** is a multi-platform delivery and moving services application focusing on transparency, safety, and accountability.

**Brand Colors:** Red (#E53935) & Blue (#1E88E5)  
**Font Family:** Urbanist (Regular, Medium, Bold)  
**Platform:** Android & iOS (Flutter)

---

## Complete Feature List

### 1. Account & Authentication
- Register with email/password or mobile number (OTP)
- Login with saved credentials
- Logout and session timeout
- Edit profile (name, contact, email, photo)
- Change password
- Request account deletion

### 2. Booking & Scheduling
- **Book Now** for immediate pickup
- **Schedule for Later** for future delivery
- Set pickup and drop-off using Google Maps
- Manual pin adjustment and address typing
- Save frequently used addresses
- Recent locations history
- Vehicle selection: Wingvan, Trailer, 6-Wheeler, 4-Wheeler, AUV
- Real-time vehicle availability
- Automatic fare computation (distance + vehicle type)
- Display estimated cost before confirmation
- Add delivery notes and special instructions

### 3. Driver Assignment & Information
- View driver name, photo, rating
- View vehicle type, plate number, photos (front/back)
- **View-only driver credentials (during active delivery):**
  - Driver's license
  - Police clearance
  - Auto-hidden after delivery completion
- Legal protection clause displayed

### 4. Real-Time Delivery Tracking
- **Delivery stages:**
  1. Arrived at pickup
  2. Start loading
  3. Finished loading
  4. Arrived at destination
  5. Start unloading
  6. Finished unloading
  7. Delivery completed
- Real-time GPS tracking on Google Maps
- Dynamic status display
- ETA and distance remaining
- View delivery proofs:
  - Receiver's digital signature
  - Receiver's name
  - Photos of each stage with GPS tags

### 5. Delivery Completion & Reports
- Automated email sent to customer and admin
- **Email format:** [PlateNumber][UnitType][Date]_[DriverName]
- Includes timeline summary and all photos as attachments
- In-app delivery summary with PDF download

### 6. Complaints & Feedback
- Submit complaints with category, description, photos
- Track complaint status
- Rate driver (1-5 stars) with categories
- Written feedback option

### 7. Cancellation Rules
- **Auto refund:** If cancelled before driver in transit
- **Investigation:** For unexpected delays/stops
- **Admin validation:** Manual cancellation with documentation
- Partial refund if delivery partially completed

### 8. Notifications & Communication
- Push notifications for all delivery stages
- Call driver directly
- In-app chat with driver
- SMS link option
- Emergency contact access
- Notification center with history

### 9. Wallet & Transaction Summary
- View wallet balance
- Top-up via card, GCash, PayMaya, bank transfer
- Transaction history (spent, refunded, pending)
- Booking summary with fare breakdown
- Export to CSV/PDF

### 10. Booking History & Records
- Filter by date, status, vehicle type
- Search by reference or location
- Detailed delivery summary:
  - Activity timeline
  - All photos with GPS
  - Receiver info and signature
  - Admin remarks
- Monthly analytics

### 11. Support & Legal
- FAQ and how-to guides
- Terms and Conditions
- Privacy Policy
- Legal notice on driver credential usage
- Live chat, email, phone support

---

## Development Phases

### Phase 1: Foundation & Authentication ✅
**Status:** COMPLETED | **Duration:** Day 1-2

**Completed:**
- Project structure (screens, utils, widgets, services)
- Theme with red/blue branding
- Urbanist fonts integration
- Professional splash screen (white, no gradients)
- Professional welcome screen (solid colors)
- User model with Firestore mapping
- Auth service (mock, ready for Firebase)
- Mobile-focused login screen (+63 format)
- Signup screen (name, phone, optional email)
- OTP verification (6-digit, 60s resend timer)
- Auto-navigation based on auth status
- UI helpers (toast, loading, snackbar)

**Files Created:**
- lib/utils/ - app_colors, app_constants, app_theme, ui_helpers
- lib/models/user_model.dart
- lib/services/auth_service.dart
- lib/screens/splash_screen.dart
- lib/screens/auth/ - welcome, login, signup, otp_verification
- lib/screens/home_screen.dart

---

### Phase 2: Account Management ✅
**Status:** COMPLETED | **Duration:** Day 2

**Completed Tasks:**
- ✅ Profile screen UI (clean, professional, no gradients)
- ✅ Edit profile functionality
- ✅ Change password screen with validation
- ✅ Profile photo upload UI (ready for Firebase Storage)
- ✅ Account deletion request dialog
- ✅ Form validation for all fields
- ✅ Settings menu items
- ✅ Support & legal links
- ✅ Logout functionality

**Files Created:**
- `lib/screens/profile/profile_screen.dart` - Profile UI with static data
- `lib/screens/profile/edit_profile_screen.dart` - Edit name, phone, email, photo
- `lib/screens/profile/change_password_screen.dart` - Password change with validation
- `lib/services/storage_service.dart` - File upload service (ready for Firebase)

**Files Modified:**
- `lib/services/auth_service.dart` - Added getCurrentUser, changePassword, requestAccountDeletion
- `lib/screens/home_screen.dart` - Integrated ProfileScreen into bottom navigation

**Note:** Wallet/Top-up system removed from customer app as per requirements

---

### Phase 3: Location & Maps Integration ✅
**Status:** COMPLETED | **Duration:** Day 2

**Completed Tasks:**
- ✅ Location model with Firestore mapping
- ✅ Location service (ready for geolocator integration)
- ✅ Maps service (ready for Google Maps API)
- ✅ Location picker screen UI
- ✅ Saved locations screen UI
- ✅ Search places functionality (mock)
- ✅ Current location detection (mock)
- ✅ Recent locations list
- ✅ Save/edit/delete favorite locations
- ✅ Distance calculation (Haversine formula)
- ✅ Fare calculation based on distance and vehicle type
- ✅ Route calculation (mock)

**Files Created:**
- `lib/models/location_model.dart` - Location data model
- `lib/services/location_service.dart` - Location permissions and geocoding
- `lib/services/maps_service.dart` - Google Maps API interactions and fare calculation
- `lib/screens/booking/location_picker_screen.dart` - Search and select locations
- `lib/screens/booking/saved_locations_screen.dart` - Manage saved locations

**Files Modified:**
- `pubspec.yaml` - Added commented location/maps packages
- `lib/utils/ui_helpers.dart` - Added showLoadingDialog method

**Note:** All services have mock implementations and are ready for Google Maps API integration

---

### Phase 4: Booking Flow ✅
**Status:** COMPLETED | **Duration:** Day 2

**Completed Tasks:**
- ✅ Booking start screen with location selection
- ✅ Book Now vs Schedule Later selection
- ✅ Date/time picker for scheduled bookings
- ✅ Vehicle selection screen with 5 types (AUV, 4-Wheeler, 6-Wheeler, Wingvan, Trailer)
- ✅ Fare calculation by vehicle type and distance
- ✅ Cost estimation display
- ✅ Delivery notes input
- ✅ Booking summary screen with fare breakdown
- ✅ Booking confirmation
- ✅ Booking service (mock, ready for Firestore)
- ✅ Vehicle and booking models

**Files Created:**
- `lib/models/vehicle_model.dart` - Vehicle types with pricing
- `lib/models/booking_model.dart` - Booking data model
- `lib/services/booking_service.dart` - Booking CRUD operations
- `lib/screens/booking/booking_start_screen.dart` - Location selection
- `lib/screens/booking/vehicle_selection_screen.dart` - Choose vehicle
- `lib/screens/booking/booking_summary_screen.dart` - Review and confirm

**Files Modified:**
- `lib/screens/home_screen.dart` - Added navigation to booking flow

**Note:** All services have mock implementations ready for Firebase integration

---

### Phase 5: Payment Integration 🔄
**Status:** PENDING | **Est. Duration:** 3-4 days

**Tasks:**
- [ ] Payment method selection
- [ ] Card payment integration (Stripe/PayMongo)
- [ ] GCash integration
- [ ] PayMaya integration
- [ ] Wallet system implementation
- [ ] Top-up functionality
- [ ] Payment capture on booking
- [ ] Transaction history screen
- [ ] Refund processing
- [ ] Receipt generation

**Required Packages:**
- lutter_stripe or paymongo_sdk
- cloud_firestore

**Files to Create:**
- lib/screens/payment/payment_method_screen.dart
- lib/screens/payment/wallet_screen.dart
- lib/screens/payment/top_up_screen.dart
- lib/screens/payment/transaction_history_screen.dart
- lib/services/payment_service.dart
- lib/models/payment_model.dart
- lib/models/transaction_model.dart

---

### Phase 6: Driver Assignment & Credentials ✅
**Status:** COMPLETED | **Duration:** Day 2

**Completed Tasks:**
- ✅ Driver model with all details
- ✅ Driver profile display with photo
- ✅ Vehicle details display (type, plate, photo)
- ✅ View driver credentials screen
- ✅ Watermarked credential images
- ✅ Auto-hide notice after delivery
- ✅ Legal protection clauses
- ✅ Driver rating and deliveries count
- ✅ Call and message driver buttons
- ✅ Copy contact information
- ✅ Verification badge for verified drivers
- ✅ Multiple watermarks on credentials
- ✅ Timestamp on credential images

**Files Created:**
- `lib/models/driver_model.dart` - Driver data model with mock data
- `lib/screens/delivery/driver_info_screen.dart` - Driver profile and contact
- `lib/screens/delivery/driver_credentials_screen.dart` - Watermarked credentials view

**Note:** Phase 5 (Payment Integration) skipped as wallet/top-up removed from customer app
- lib/widgets/credential_viewer.dart

---

### Phase 7: Real-Time Tracking 🔄
**Status:** PENDING | **Est. Duration:** 5-6 days

**Tasks:**
- [ ] Real-time database setup (Firestore)
- [ ] Live tracking screen with Google Maps
- [ ] Driver location updates (real-time)
- [ ] Delivery stage status updates
- [ ] Route visualization with polyline
- [ ] ETA calculation
- [ ] Distance remaining display
- [ ] Delivery proof viewer:
  - Photo gallery by stage
  - Digital signature display
  - Receiver name display
  - GPS tags on photos
- [ ] Activity timeline UI

**Required Packages:**
- cloud_firestore
- irebase_database
- lutter_polyline_points

**Files to Create:**
- lib/screens/delivery/live_tracking_screen.dart
- lib/screens/delivery/delivery_proof_screen.dart
- lib/screens/delivery/photo_gallery_screen.dart
- lib/services/tracking_service.dart
- lib/models/delivery_stage_model.dart
- lib/widgets/tracking_map.dart
- lib/widgets/timeline_widget.dart

---

### Phase 8: Delivery Completion & Reports 🔄
**Status:** PENDING | **Est. Duration:** 3 days

**Tasks:**
- [ ] Delivery completion handler
- [ ] Automated email generation
- [ ] Email template with photos
- [ ] PDF report generation
- [ ] In-app delivery summary
- [ ] Download report functionality
- [ ] Share delivery summary
- [ ] Print-friendly format

**Required Packages:**
- mailer or Firebase Cloud Functions
- pdf
- share_plus

**Files to Create:**
- lib/screens/delivery/delivery_summary_screen.dart
- lib/services/email_service.dart
- lib/services/report_service.dart
- lib/utils/pdf_generator.dart

---

### Phase 9: Complaints & Feedback 🔄
**Status:** PENDING | **Est. Duration:** 2-3 days

**Tasks:**
- [ ] Complaint submission screen
- [ ] Complaint categories
- [ ] Photo attachment (up to 5)
- [ ] Complaint tracking
- [ ] Rating screen (1-5 stars)
- [ ] Rating categories
- [ ] Written feedback input
- [ ] Anonymous feedback option
- [ ] View driver ratings

**Files to Create:**
- lib/screens/feedback/complaint_screen.dart
- lib/screens/feedback/rating_screen.dart
- lib/services/feedback_service.dart
- lib/models/complaint_model.dart
- lib/models/rating_model.dart

---

### Phase 10: Cancellation System 🔄
**Status:** PENDING | **Est. Duration:** 2 days

**Tasks:**
- [ ] Cancel booking functionality
- [ ] Cancellation reason selection
- [ ] Auto-refund logic
- [ ] Investigation request
- [ ] Admin validation interface
- [ ] Partial refund calculation
- [ ] Cancellation history

**Files to Create:**
- lib/screens/booking/cancel_booking_screen.dart
- lib/services/cancellation_service.dart
- lib/models/cancellation_model.dart

---

### Phase 11: Communication Tools 🔄
**Status:** PENDING | **Est. Duration:** 3 days

**Tasks:**
- [ ] Call driver functionality (url_launcher)
- [ ] In-app chat with driver
- [ ] SMS link integration
- [ ] Emergency contact button
- [ ] Share tracking link
- [ ] Notification center
- [ ] Push notification setup (FCM)

**Required Packages:**
- irebase_messaging
- lutter_local_notifications
- url_launcher
- share_plus

**Files to Create:**
- lib/screens/communication/chat_screen.dart
- lib/screens/notifications/notification_center_screen.dart
- lib/services/notification_service.dart
- lib/services/chat_service.dart

---

### Phase 12: Wallet & Transactions 🔄
**Status:** PENDING | **Est. Duration:** 3 days

**Tasks:**
- [ ] Wallet balance display
- [ ] Top-up screen with payment methods
- [ ] Auto-reload settings
- [ ] Transaction list with filters
- [ ] Booking financial summary
- [ ] Export to CSV/PDF
- [ ] Monthly analytics

**Files to Create:**
- lib/screens/wallet/wallet_dashboard_screen.dart
- lib/screens/wallet/transaction_list_screen.dart
- lib/services/wallet_service.dart
- lib/utils/csv_exporter.dart

---

### Phase 13: Booking History 🔄
**Status:** PENDING | **Est. Duration:** 3 days

**Tasks:**
- [ ] Booking list with filters
- [ ] Search functionality
- [ ] Detailed booking view
- [ ] Activity timeline display
- [ ] Photo gallery viewer
- [ ] Admin remarks display
- [ ] Monthly analytics dashboard

**Files to Create:**
- lib/screens/history/booking_history_screen.dart
- lib/screens/history/booking_detail_screen.dart
- lib/widgets/booking_card.dart
- lib/widgets/analytics_chart.dart

---

### Phase 14: Support & Legal 🔄
**Status:** PENDING | **Est. Duration:** 2 days

**Tasks:**
- [ ] FAQ screen with search
- [ ] How-to guides
- [ ] Terms and Conditions viewer
- [ ] Privacy Policy viewer
- [ ] Legal notice display
- [ ] Contact support screen
- [ ] Live chat integration
- [ ] Feedback submission

**Files to Create:**
- lib/screens/support/help_center_screen.dart
- lib/screens/support/faq_screen.dart
- lib/screens/support/legal_documents_screen.dart
- lib/screens/support/contact_support_screen.dart

---

### Phase 15: Testing & Polish 🔄
**Status:** PENDING | **Est. Duration:** 4-5 days

**Tasks:**
- [ ] Unit tests for services
- [ ] Widget tests for screens
- [ ] Integration tests
- [ ] End-to-end testing
- [ ] Error handling improvements
- [ ] Loading states optimization
- [ ] UI/UX refinements
- [ ] Performance optimization
- [ ] Accessibility improvements
- [ ] Bug fixes

---

### Phase 16: Deployment 🔄
**Status:** PENDING | **Est. Duration:** 3-4 days

**Tasks:**
- [ ] App icon finalization
- [ ] Splash screen assets
- [ ] Android build configuration
- [ ] iOS build configuration
- [ ] Play Store listing
- [ ] App Store listing
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
- **Email:** Firebase Cloud Functions + SendGrid

### Key Packages
\\\yaml
dependencies:
  flutter_spinkit: ^5.2.0
  fluttertoast: ^8.2.4
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
  firebase_storage: ^latest
  google_maps_flutter: ^latest
  geolocator: ^latest
  geocoding: ^latest
  google_places_flutter: ^latest
  firebase_messaging: ^latest
  flutter_local_notifications: ^latest
  url_launcher: ^latest
  share_plus: ^latest
  pdf: ^latest
  intl: ^0.20.2
\\\

---

## Database Structure (Firestore)

### Collections

#### users
\\\
{
  userId: string
  name: string
  email: string
  phone: string
  photoUrl: string
  userType: "customer"
  walletBalance: number
  savedLocations: array
  createdAt: timestamp
  updatedAt: timestamp
}
\\\

#### bookings
\\\
{
  bookingId: string
  customerId: string
  driverId: string
  pickupLocation: geopoint
  dropoffLocation: geopoint
  pickupAddress: string
  dropoffAddress: string
  vehicleType: string
  bookingType: string (now/scheduled)
  scheduledDateTime: timestamp
  distance: number
  estimatedCost: number
  finalCost: number
  status: string
  deliveryStages: array
  notes: string
  createdAt: timestamp
  completedAt: timestamp
}
\\\

#### delivery_stages
\\\
{
  stageId: string
  bookingId: string
  stageName: string
  timestamp: timestamp
  location: geopoint
  photos: array
  notes: string
}
\\\

#### complaints
\\\
{
  complaintId: string
  bookingId: string
  customerId: string
  category: string
  description: string
  photos: array
  status: string
  adminResponse: string
  createdAt: timestamp
  resolvedAt: timestamp
}
\\\

#### ratings
\\\
{
  ratingId: string
  bookingId: string
  driverId: string
  customerId: string
  overallRating: number
  categories: object
  feedback: string
  createdAt: timestamp
}
\\\

---

## Change Log

### Day 1 - Oct 15, 2025
**Foundation Setup**
- Created project structure
- Implemented theme system with red/blue branding
- Integrated Urbanist custom fonts
- Built animated splash screen
- Created home screen with bottom navigation
- Added UI helper utilities
- Configured app constants and API keys
- Set up portrait-only orientation

**Files Added:**
- lib/utils/app_colors.dart
- lib/utils/app_constants.dart
- lib/utils/app_theme.dart
- lib/utils/ui_helpers.dart
- lib/screens/splash_screen.dart
- lib/screens/home_screen.dart

### Day 2 - Oct 16, 2025
**Authentication System**
- Created user model with Firestore mapping
- Built authentication service with mock implementation
- Designed welcome screen with gradient branding
- Implemented mobile number focused login screen
- Built signup screen with name, phone, and optional email
- Created OTP verification screen with 6-digit input
- Added OTP resend functionality with 60-second countdown
- Implemented auto-navigation based on authentication status
- Added form validation for all input fields
- Integrated Philippine phone number format (+63)
- Added terms and conditions checkbox
- Created social login UI placeholders

**UI Redesign (Professional Update):**
- Redesigned splash screen with clean white background (removed gradient)
- Changed logo from circle to rounded square with red background
- Updated typography for better readability
- Redesigned welcome screen with solid colors (removed gradient)
- Updated button styles for more professional appearance
- Improved spacing and layout consistency

**Files Added:**
- lib/models/user_model.dart
- lib/services/auth_service.dart
- lib/screens/auth/welcome_screen.dart
- lib/screens/auth/login_screen.dart
- lib/screens/auth/signup_screen.dart
- lib/screens/auth/otp_verification_screen.dart

**Files Modified:**
- lib/screens/splash_screen.dart
- lib/screens/auth/welcome_screen.dart
- lib/screens/auth/login_screen.dart
- lib/screens/auth/signup_screen.dart

**Development Plan Updated:**
- Comprehensive feature list added based on complete requirements
- All 11 feature categories documented in detail
- 16 development phases outlined
- Database structure defined
- Technical stack finalized

**Account Management (Phase 2 Completed):**
- Built professional profile screen (clean white background, no gradients)
- Profile photo display with edit button
- Account section (Edit Profile, Change Password)
- Settings section (Notifications, Language)
- Support section (Help Center, Terms, Privacy)
- Danger zone (Logout, Delete Account)
- Created edit profile screen with photo upload UI
- Full name, phone number, email editing with static placeholder data
- Form validation for all fields
- Created change password screen
- Current, new, and confirm password fields
- Strong password validation (8+ chars, uppercase, lowercase, numbers)
- Created storage service for file uploads (ready for Firebase)
- Updated auth service with new methods
- No data fetching - UI only with static data
- Wallet/Top-up system removed from customer app

**Files Added:**
- lib/screens/profile/profile_screen.dart
- lib/screens/profile/edit_profile_screen.dart
- lib/screens/profile/change_password_screen.dart
- lib/services/storage_service.dart

**Files Modified:**
- lib/services/auth_service.dart
- lib/screens/home_screen.dart

---

*Last Updated: Oct 16, 2025*
