# CitiMovers Rider/Driver App - Setup Complete

## Overview
The rider/driver authentication flow has been successfully created with a separate folder structure from the user app.

## Folder Structure

```
lib/
├── rider/
│   ├── models/
│   │   └── rider_model.dart          # Rider data model
│   ├── services/
│   │   └── rider_auth_service.dart   # Authentication service for riders
│   └── screens/
│       ├── auth/
│       │   ├── rider_splash_screen.dart           # Animated splash screen
│       │   ├── rider_onboarding_screen.dart       # 5-page onboarding
│       │   ├── rider_login_screen.dart            # Login with phone
│       │   ├── rider_signup_screen.dart           # Registration form
│       │   └── rider_otp_verification_screen.dart # OTP verification
│       └── rider_home_screen.dart     # Main home screen (placeholder)
```

## Features Implemented

### 1. Rider Splash Screen (`rider_splash_screen.dart`)
- **Gradient background** with red theme
- **Animated logo** with rotation and scale effects
- **"RIDER" badge** to distinguish from user app
- **Auto-navigation** to onboarding or login based on user state
- Checks for `hasSeenRiderOnboarding` preference

### 2. Rider Onboarding Screen (`rider_onboarding_screen.dart`)
- **5 pages** with driver-specific content:
  1. Earn Money on Your Schedule
  2. Real-Time Navigation
  3. Instant Notifications
  4. Track Your Earnings
  5. Safe & Secure
- **Smooth animations** for icons, titles, and descriptions
- **Skip button** for quick access
- **Animated page indicators**
- Saves `hasSeenRiderOnboarding` preference

### 3. Rider Login Screen (`rider_login_screen.dart`)
- **"RIDER LOGIN" badge** at the top
- **Phone number input** with +63 prefix
- **Philippine flag** icon
- **Validation** for phone numbers
- **Info card** highlighting earning opportunities
- **Create Rider Account** button for new riders
- OTP-based authentication

### 4. Rider Signup Screen (`rider_signup_screen.dart`)
- **"BECOME A RIDER" badge**
- **Registration fields**:
  - Full Name (required)
  - Mobile Number (required)
  - Email Address (optional)
  - Vehicle Type (dropdown: Motorcycle, Sedan, Van, Truck)
- **Terms and Conditions** checkbox
- **Form validation**
- Checks if phone is already registered

### 5. Rider OTP Verification Screen (`rider_otp_verification_screen.dart`)
- **6-digit OTP input** with individual fields
- **Auto-focus** on next field
- **Auto-verify** when all digits entered
- **Resend OTP** with 60-second countdown timer
- **Expiration notice** (10 minutes)
- Handles both signup and login flows

### 6. Rider Auth Service (`rider_auth_service.dart`)
- **Singleton pattern** for global access
- **Methods**:
  - `sendOTP()` - Send OTP to phone
  - `verifyOTP()` - Verify OTP code
  - `registerRider()` - Register new rider with vehicle info
  - `loginRider()` - Login existing rider
  - `isPhoneRegistered()` - Check phone registration
  - `logout()` - Logout rider
  - `getCurrentRider()` - Get current rider data
  - `updateProfile()` - Update rider profile
  - `toggleOnlineStatus()` - Toggle online/offline
  - `updateLocation()` - Update rider location
- Currently uses mock data (ready for Firebase integration)

### 7. Rider Model (`rider_model.dart`)
- **Complete rider data structure**:
  - Basic info (name, phone, email, photo)
  - Vehicle details (type, plate, model, color)
  - Status (pending, approved, active, inactive, suspended)
  - Online status
  - Performance metrics (rating, total deliveries, earnings)
  - Location (latitude, longitude)
  - Timestamps
- **JSON serialization** methods
- **CopyWith** method for immutable updates

### 8. Rider Home Screen (`rider_home_screen.dart`)
- **Header** with rider profile
- **Rating and delivery count** display
- **Online/Offline toggle** switch
- **Logout functionality**
- Placeholder for future features

## Design Highlights

### Color Scheme
- **Primary**: Red gradient (matching CitiMovers brand)
- **Accent**: White for contrast
- **Status colors**: Green for online, Grey for offline

### Animations
- **Splash**: Fade, scale, and rotation animations
- **Onboarding**: Icon bounce, title/description slide-in
- **Buttons**: Scale animations with shadows
- **Page transitions**: Smooth fade transitions

### UI/UX Features
- **Consistent branding** with "RIDER" badges
- **Modern card designs** with shadows
- **Responsive layouts**
- **Toast notifications** for user feedback
- **Loading indicators** during async operations
- **Form validation** with helpful error messages

## How to Use

### To Test Rider App Flow:

1. **Run the rider splash screen**:
   ```dart
   // In main.dart or create a separate rider_main.dart
   runApp(MaterialApp(
     home: RiderSplashScreen(),
   ));
   ```

2. **Flow sequence**:
   - Splash Screen (3 seconds)
   - Onboarding (first time only)
   - Login Screen
   - OTP Verification
   - Home Screen

3. **Test credentials**:
   - Any phone starting with `+639` is considered "registered"
   - Any 6-digit OTP code will be accepted (mock)

## Next Steps

### Recommended Implementations:

1. **Firebase Integration**:
   - Replace mock auth with Firebase Phone Auth
   - Implement Firestore for rider data
   - Add real-time location tracking

2. **Rider Features**:
   - Delivery request notifications
   - Accept/Reject delivery screen
   - Navigation to pickup/delivery
   - Earnings dashboard
   - Delivery history
   - Profile management

3. **Vehicle Management**:
   - Vehicle registration with photos
   - Document upload (license, registration)
   - Vehicle verification status

4. **Earnings & Payments**:
   - Daily/weekly earnings tracker
   - Withdrawal system
   - Payment history
   - Tips tracking

5. **Real-time Features**:
   - Live location updates
   - Customer chat
   - In-app navigation
   - Delivery status updates

## File Relationships

```
rider_splash_screen.dart
    ↓
rider_onboarding_screen.dart
    ↓
rider_login_screen.dart ←→ rider_signup_screen.dart
    ↓                           ↓
rider_otp_verification_screen.dart
    ↓
rider_home_screen.dart
```

All screens use:
- `rider_auth_service.dart` for authentication
- `rider_model.dart` for data structure
- Shared `utils/` for colors, themes, and helpers

## Notes

- **Separate from user app**: Complete isolation in `lib/rider/` folder
- **Ready for scaling**: Service-based architecture
- **Mock data**: Easy to replace with real backend
- **Consistent design**: Follows user app patterns
- **Production-ready UI**: Polished animations and interactions

---

**Created**: November 2024  
**Status**: ✅ Complete and ready for integration
