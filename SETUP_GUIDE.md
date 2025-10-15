# CitiMovers - Setup Guide

## Project Structure

The CitiMovers app has been set up with a professional structure and beautiful UI components.

### Folder Structure

```
lib/
├── screens/          # All app screens
│   ├── splash_screen.dart
│   └── home_screen.dart
├── utils/           # Utilities, colors, constants
│   ├── app_colors.dart
│   ├── app_constants.dart
│   ├── app_theme.dart
│   └── ui_helpers.dart
├── widgets/         # Custom reusable widgets
└── services/        # Backend services and API calls
```

## Features Implemented

### 1. **Theme Configuration**
- **Colors**: Red (#E53935) and Blue (#1E88E5) color scheme
- **Fonts**: Urbanist font family (Regular, Medium, Bold)
- **Material 3**: Modern design system
- **Dark Mode**: Full dark theme support

### 2. **Splash Screen**
- Professional animated splash screen
- Gradient background with decorative elements
- Smooth fade and scale animations
- Loading indicator using `flutter_spinkit`
- Auto-navigation to home screen after 3 seconds
- Fade transition between screens

### 3. **Home Screen**
- Beautiful gradient header
- Quick action cards
- Vehicle type selection cards
- Bottom navigation bar (Home, Bookings, Profile)
- Professional UI with shadows and rounded corners

### 4. **UI Helpers**
Located in `lib/utils/ui_helpers.dart`:

#### Loading Indicators (using flutter_spinkit):
- `UIHelpers.loadingIndicator()` - Fading circle
- `UIHelpers.loadingSpinner()` - Circle spinner
- `UIHelpers.loadingRotatingCircle()` - Rotating circle
- `UIHelpers.loadingWave()` - Wave animation
- `UIHelpers.loadingThreeBounce()` - Three bouncing dots
- `UIHelpers.loadingOverlay()` - Full screen overlay

#### Toast Messages (using fluttertoast):
- `UIHelpers.showSuccessToast()` - Green success message
- `UIHelpers.showErrorToast()` - Red error message
- `UIHelpers.showInfoToast()` - Blue info message
- `UIHelpers.showWarningToast()` - Yellow warning message
- `UIHelpers.showToast()` - Custom toast

#### Snackbars:
- `UIHelpers.showSnackBar()` - Material snackbar with actions
- `UIHelpers.showLoadingBottomSheet()` - Loading bottom sheet

## Usage Examples

### Show Loading Indicator
```dart
Center(
  child: UIHelpers.loadingIndicator(),
)
```

### Show Toast Message
```dart
// Success
UIHelpers.showSuccessToast('Order placed successfully!');

// Error
UIHelpers.showErrorToast('Something went wrong');

// Info
UIHelpers.showInfoToast('Processing your request');

// Warning
UIHelpers.showWarningToast('Please check your input');
```

### Show Snackbar
```dart
UIHelpers.showSnackBar(
  context,
  'Item added to cart',
  actionLabel: 'UNDO',
  onAction: () {
    // Handle undo action
  },
);
```

### Use Custom Colors
```dart
Container(
  color: AppColors.primaryRed,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.white),
  ),
)
```

### Use Gradient
```dart
Container(
  decoration: BoxDecoration(
    gradient: AppColors.primaryGradient,
  ),
)
```

## Constants Available

### App Information
- `AppConstants.appName` - "CitiMovers"
- `AppConstants.appVersion` - "1.0.0"
- `AppConstants.appTagline` - "Your Reliable Delivery Partner"
- `AppConstants.apiKey` - Google Maps API Key

### User Types
- `AppConstants.userTypeCustomer`
- `AppConstants.userTypeDriver`
- `AppConstants.userTypeAdmin`

### Booking Status
- `AppConstants.bookingPending`
- `AppConstants.bookingAccepted`
- `AppConstants.bookingInProgress`
- `AppConstants.bookingCompleted`
- `AppConstants.bookingCancelled`

### Vehicle Types
- `AppConstants.vehicleMotorcycle`
- `AppConstants.vehicleSedan`
- `AppConstants.vehicleVan`
- `AppConstants.vehicleTruck`

## Design Guidelines

### Typography
- **Display**: Bold font for large headings
- **Headline**: Bold/Medium for section headers
- **Title**: Medium for card titles
- **Body**: Regular for content text
- **Label**: Regular/Medium for labels

### Spacing
- Small: 8px
- Medium: 16px
- Large: 24px
- Extra Large: 32px

### Border Radius
- Small: 8px
- Medium: 12px
- Large: 16px
- Extra Large: 20px

### Elevation
- Cards: 2px
- Buttons: 2px
- Bottom Nav: 8px

## Next Steps

1. **Authentication**: Implement login/register screens
2. **Firebase**: Set up Firebase for backend
3. **Maps**: Integrate Google Maps for location services
4. **Booking Flow**: Create booking screens
5. **Driver App**: Build driver-specific features
6. **Admin Dashboard**: Create web admin panel

## Running the App

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

The app will start with the splash screen and automatically navigate to the home screen after 3 seconds.
