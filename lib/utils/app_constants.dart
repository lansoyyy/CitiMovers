/// App-wide constants for CitiMovers
class AppConstants {
  AppConstants._();

  static String logo = 'assets/images/logo.png';
  static const String apiKey = 'AIzaSyBwByaaKz7j4OGnwPDxeMdmQ4Pa50GA42o';
  // App Information
  static const String appName = 'CitiMovers';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Reliable Delivery Partner';

  // API & Backend
  static const String baseUrl = 'https://api.citimovers.com';
  static const int apiTimeout = 30; // seconds

  // Shared Preferences Keys
  static const String keyUserId = 'user_id';
  static const String keyUserType = 'user_type';
  static const String keyAuthToken = 'auth_token';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserData = 'user_data';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';

  // User Types
  static const String userTypeCustomer = 'customer';
  static const String userTypeDriver = 'driver';
  static const String userTypeAdmin = 'admin';

  // Firebase Collections
  static const String collectionUsers = 'users';
  static const String collectionDrivers = 'drivers';
  static const String collectionCustomers = 'customers';
  static const String collectionBookings = 'bookings';
  static const String collectionVehicles = 'vehicles';
  static const String collectionPayments = 'payments';
  static const String collectionNotifications = 'notifications';

  // Booking Status
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';
  static const String bookingInProgress = 'in_progress';
  static const String bookingCompleted = 'completed';
  static const String bookingCancelled = 'cancelled';

  // Vehicle Types
  static const String vehicleMotorcycle = 'motorcycle';
  static const String vehicleSedan = 'sedan';
  static const String vehicleVan = 'van';
  static const String vehicleTruck = 'truck';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 20;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;

  // Map Settings
  static const double defaultZoom = 15.0;
  static const double defaultLatitude = 14.5995; // Manila, Philippines
  static const double defaultLongitude = 120.9842;

  // Pagination
  static const int itemsPerPage = 20;
  static const int maxLoadMoreAttempts = 3;

  // Animation Durations (milliseconds)
  static const int shortAnimationDuration = 200;
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;

  // Image Settings
  static const int maxImageSizeKB = 2048; // 2MB
  static const int imageQuality = 85;

  // Support Contact
  static const String supportPhone = '09090104355';
  static const String supportEmail = 'support@citimovers.com';

  // Privacy Policy Contact
  static const String privacyEmail = 'privacy@citimovers.com';
  static const String dpoEmail = 'dpo@citimovers.com';
  static const String hotlinePhone = '+63 2 8123 4567';
  static const String officeAddress =
      '123 Delivery Street, Manila, Philippines';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'No internet connection. Please check your network.';
  static const String errorTimeout = 'Request timeout. Please try again.';
  static const String errorUnauthorized =
      'Session expired. Please login again.';
}
