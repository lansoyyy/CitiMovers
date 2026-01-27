import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSchemaSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> seed() async {
    final now = DateTime.now().toIso8601String();

    await _firestore.collection('meta').doc('schema').set(
      {
        'version': 1,
        'updatedAt': now,
        'collections': {
          'users': {
            'docId': 'userId',
            'fields': {
              'userId': 'string',
              'name': 'string',
              'phoneNumber': 'string',
              'email': 'string?',
              'photoUrl': 'string?',
              'userType': 'string',
              'walletBalance': 'number',
              'favoriteLocations': 'array<string>',
              'emailVerified': 'bool?',
              'createdAt': 'string(iso8601)',
              'updatedAt': 'string(iso8601)',
            },
          },
          'riders': {
            'docId': 'riderId',
            'fields': {
              'riderId': 'string',
              'name': 'string',
              'phoneNumber': 'string',
              'email': 'string?',
              'photoUrl': 'string?',
              'vehicleType': 'string',
              'vehiclePlateNumber': 'string?',
              'vehicleModel': 'string?',
              'vehicleColor': 'string?',
              'status': 'string',
              'isOnline': 'bool',
              'rating': 'number',
              'totalDeliveries': 'number',
              'totalEarnings': 'number',
              'currentLatitude': 'number?',
              'currentLongitude': 'number?',
              'createdAt': 'string(iso8601)',
              'updatedAt': 'string(iso8601)',
              'documents': 'map<docKey, {name,url,status,uploadedAt}>',
              'documentsUpdatedAt': 'string(iso8601)?',
            },
          },
          'bookings': {
            'docId': 'bookingId',
            'fields': {
              'bookingId': 'string',
              'customerId': 'string',
              'driverId': 'string?',
              'pickupLocation': 'map',
              'dropoffLocation': 'map',
              'vehicle': 'map',
              'bookingType': 'string',
              'scheduledDateTime': 'number?',
              'distance': 'number',
              'estimatedFare': 'number',
              'finalFare': 'number?',
              'status': 'string',
              'paymentMethod': 'string',
              'notes': 'string?',
              'createdAt': 'number',
              'completedAt': 'number?',
              'cancellationReason': 'string?',
              'insuranceCoverage': 'number?',
              'tipAmount': 'number?',
              'demurrageCharges': 'number?',
              'loadingStartTime': 'number?',
              'loadingEndTime': 'number?',
              'unloadingStartTime': 'number?',
              'unloadingEndTime': 'number?',
            },
          },
          'saved_locations': {
            'docId': 'locationId',
            'fields': {
              'userId': 'string',
              'name': 'string',
              'address': 'string',
              'latitude': 'number',
              'longitude': 'number',
              'type': 'string?',
              'createdAt': 'timestamp',
              'updatedAt': 'timestamp',
            },
          },
          'email_notifications': {
            'docId': 'id',
            'fields': {
              'to': 'string',
              'subject': 'string',
              'htmlBody': 'string',
              'textBody': 'string?',
              'templateId': 'string?',
              'templateData': 'map?',
              'type': 'string',
              'referenceId': 'string?',
              'isSent': 'bool',
              'sentAt': 'timestamp?',
              'errorMessage': 'string?',
              'createdAt': 'timestamp',
            },
          },
          'rider_settings': {
            'docId': 'riderId',
            'fields': {
              'riderId': 'string',
              'pushNotifications': 'bool',
              'emailNotifications': 'bool',
              'smsNotifications': 'bool',
              'soundEffects': 'bool',
              'vibration': 'bool',
              'locationServices': 'bool',
              'autoAcceptDeliveries': 'bool',
              'language': 'string',
              'theme': 'string',
              'createdAt': 'timestamp',
              'updatedAt': 'timestamp',
            },
          },
          'promo_banners': {
            'docId': 'bannerId',
            'fields': {
              'title': 'string',
              'description': 'string',
              'imageUrl': 'string',
              'actionUrl': 'string?',
              'isActive': 'bool',
              'startDate': 'timestamp?',
              'endDate': 'timestamp?',
              'displayOrder': 'number',
              'createdAt': 'timestamp',
              'updatedAt': 'timestamp',
            },
          },
          'payment_methods': {
            'docId': 'paymentMethodId',
            'fields': {
              'userId': 'string',
              'type': 'string',
              'name': 'string',
              'accountNumber': 'string',
              'accountName': 'string',
              'isDefault': 'bool',
              'createdAt': 'timestamp',
              'updatedAt': 'timestamp',
            },
          },
          'wallet_transactions': {
            'docId': 'transactionId',
            'fields': {
              'userId': 'string',
              'type': 'string',
              'amount': 'number',
              'balance': 'number',
              'description': 'string',
              'referenceId': 'string?',
              'createdAt': 'timestamp',
            },
          },
          'vehicles': {
            'docId': 'id',
            'fields': {
              'id': 'string',
              'name': 'string',
              'type': 'string',
              'description': 'string',
              'baseFare': 'number',
              'perKmRate': 'number',
              'capacity': 'string',
              'features': 'array<string>',
              'imageUrl': 'string',
              'isAvailable': 'bool',
            },
          },
          'payments': {
            'docId': 'paymentId',
            'fields': {
              'paymentId': 'string',
              'bookingId': 'string?',
              'payerId': 'string?',
              'payeeId': 'string?',
              'amount': 'number',
              'method': 'string',
              'status': 'string',
              'createdAt': 'string(iso8601)',
              'updatedAt': 'string(iso8601)',
              'metadata': 'map?',
            },
          },
          'notifications': {
            'docId': 'notificationId',
            'fields': {
              'notificationId': 'string',
              'recipientId': 'string',
              'recipientType': 'string',
              'title': 'string',
              'message': 'string',
              'type': 'string',
              'isUnread': 'bool',
              'bookingId': 'string?',
              'amount': 'number?',
              'createdAt': 'string(iso8601)',
              'data': 'map?',
            },
          },
        },
      },
      SetOptions(merge: true),
    );

    // Sample Customer Users
    await _firestore.collection('users').doc('+6391234567').set(
      {
        'userId': '+6391234567',
        'name': 'Juan Dela Cruz',
        'phoneNumber': '+6391234567',
        'email': 'juan.delacruz@example.com',
        'photoUrl': null,
        'userType': 'customer',
        'walletBalance': 5000.00,
        'favoriteLocations': <String>[],
        'emailVerified': true,
        'createdAt': now,
        'updatedAt': now,
      },
    );

    await _firestore.collection('users').doc('+6399876543').set(
      {
        'userId': '+6399876543',
        'name': 'Maria Santos',
        'phoneNumber': '+6399876543',
        'email': 'maria.santos@example.com',
        'photoUrl': null,
        'userType': 'customer',
        'walletBalance': 2500.00,
        'favoriteLocations': <String>[],
        'emailVerified': true,
        'createdAt': now,
        'updatedAt': now,
      },
    );

    // Sample Riders
    await _firestore.collection('riders').doc('RIDER001').set(
      {
        'riderId': 'RIDER001',
        'name': 'Pedro Reyes',
        'phoneNumber': '+6395551234',
        'email': 'pedro.reyes@example.com',
        'photoUrl': null,
        'vehicleType': '4-Wheeler',
        'vehiclePlateNumber': 'ABC 1234',
        'vehicleModel': 'Toyota Hiace',
        'vehicleColor': 'White',
        'status': 'available',
        'isOnline': true,
        'rating': 4.8,
        'totalDeliveries': 156,
        'totalEarnings': 45000.00,
        'currentLatitude': 14.5995,
        'currentLongitude': 120.9842,
        'documents': {
          'drivers_license': {
            'name': "Driver's License",
            'url': 'https://example.com/license/rider001.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
          'vehicle_registration': {
            'name': 'Vehicle Registration (OR/CR)',
            'url': 'https://example.com/orcr/rider001.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
          'nbi_clearance': {
            'name': 'NBI Clearance',
            'url': 'https://example.com/nbi/rider001.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
          'insurance': {
            'name': 'Insurance',
            'url': 'https://example.com/insurance/rider001.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
        },
        'documentsUpdatedAt': now,
        'createdAt': now,
        'updatedAt': now,
      },
    );

    await _firestore.collection('riders').doc('RIDER002').set(
      {
        'riderId': 'RIDER002',
        'name': 'Ana Garcia',
        'phoneNumber': '+6395555678',
        'email': 'ana.garcia@example.com',
        'photoUrl': null,
        'vehicleType': '6-Wheeler',
        'vehiclePlateNumber': 'XYZ 5678',
        'vehicleModel': 'Isuzu Elf',
        'vehicleColor': 'Blue',
        'status': 'available',
        'isOnline': false,
        'rating': 4.5,
        'totalDeliveries': 89,
        'totalEarnings': 28500.00,
        'currentLatitude': null,
        'currentLongitude': null,
        'documents': {
          'drivers_license': {
            'name': "Driver's License",
            'url': 'https://example.com/license/rider002.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
          'vehicle_registration': {
            'name': 'Vehicle Registration (OR/CR)',
            'url': 'https://example.com/orcr/rider002.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
          'nbi_clearance': {
            'name': 'NBI Clearance',
            'url': 'https://example.com/nbi/rider002.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
          'insurance': {
            'name': 'Insurance',
            'url': 'https://example.com/insurance/rider002.jpg',
            'status': 'verified',
            'uploadedAt': now,
          },
        },
        'documentsUpdatedAt': now,
        'createdAt': now,
        'updatedAt': now,
      },
    );

    // Sample Saved Locations
    await _firestore
        .collection('users')
        .doc('+6391234567')
        .collection('saved_locations')
        .doc('HOME001')
        .set(
      {
        'userId': '+6391234567',
        'name': 'Home',
        'address': '123 Main Street, Brgy. Poblacion, Makati City',
        'latitude': 14.5607,
        'longitude': 121.0198,
        'type': 'home',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore
        .collection('users')
        .doc('+6391234567')
        .collection('saved_locations')
        .doc('OFFICE001')
        .set(
      {
        'userId': '+6391234567',
        'name': 'Office',
        'address': '456 Corporate Ave, BGC, Taguig City',
        'latitude': 14.5116,
        'longitude': 121.0428,
        'type': 'office',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Sample Promo Banners
    await _firestore.collection('promo_banners').doc('PROMO001').set(
      {
        'title': '50% Off First Delivery',
        'description':
            'Get 50% discount on your first delivery with CitiMovers!',
        'imageUrl': 'https://example.com/promos/50off.jpg',
        'actionUrl': null,
        'isActive': true,
        'startDate': DateTime.now().millisecondsSinceEpoch,
        'endDate':
            DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        'displayOrder': 1,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore.collection('promo_banners').doc('PROMO002').set(
      {
        'title': 'Free Delivery Within Metro Manila',
        'description':
            'Free delivery for orders above ₱5,000 within Metro Manila only.',
        'imageUrl': 'https://example.com/promos/freedelivery.jpg',
        'actionUrl': null,
        'isActive': true,
        'startDate': DateTime.now().millisecondsSinceEpoch,
        'endDate':
            DateTime.now().add(const Duration(days: 14)).millisecondsSinceEpoch,
        'displayOrder': 2,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Sample Payment Methods
    await _firestore.collection('payment_methods').doc('PAYMENT001').set(
      {
        'userId': '+6391234567',
        'type': 'gcash',
        'name': 'GCash',
        'accountNumber': '09171234567',
        'accountName': 'Juan Dela Cruz',
        'isDefault': true,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore.collection('payment_methods').doc('PAYMENT002').set(
      {
        'userId': '+6391234567',
        'type': 'paymaya',
        'name': 'PayMaya',
        'accountNumber': '09189876543',
        'accountName': 'Juan Dela Cruz',
        'isDefault': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Sample Wallet Transactions
    await _firestore.collection('wallet_transactions').doc('TXN001').set(
      {
        'userId': '+6391234567',
        'type': 'top_up',
        'amount': 5000.00,
        'balance': 5000.00,
        'description': 'Initial wallet top-up',
        'referenceId': 'REF001',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore.collection('wallet_transactions').doc('TXN002').set(
      {
        'userId': '+6391234567',
        'type': 'payment',
        'amount': -850.00,
        'balance': 4150.00,
        'description': 'Payment for booking BK001',
        'referenceId': 'BK001',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Sample Vehicles
    await _firestore.collection('vehicles').doc('VEH001').set(
      {
        'id': 'VEH001',
        'name': 'Motorcycle',
        'type': 'motorcycle',
        'description': 'Small motorcycle for quick deliveries',
        'baseFare': 50.00,
        'perKmRate': 15.00,
        'capacity': 'Small (up to 20kg)',
        'features': <String>['Quick', 'Affordable', 'Maneuverable'],
        'imageUrl': 'https://example.com/vehicles/motorcycle.jpg',
        'isAvailable': true,
      },
    );

    await _firestore.collection('vehicles').doc('VEH002').set(
      {
        'id': 'VEH002',
        'name': 'Sedan',
        'type': 'sedan',
        'description': 'Standard sedan for medium deliveries',
        'baseFare': 150.00,
        'perKmRate': 25.00,
        'capacity': 'Medium (up to 200kg)',
        'features': <String>['Comfortable', 'Air-conditioned', 'Secure'],
        'imageUrl': 'https://example.com/vehicles/sedan.jpg',
        'isAvailable': true,
      },
    );

    await _firestore.collection('vehicles').doc('VEH003').set(
      {
        'id': 'VEH003',
        'name': '4-Wheeler',
        'type': '4-wheeler',
        'description': 'Light truck for larger deliveries',
        'baseFare': 300.00,
        'perKmRate': 45.00,
        'capacity': 'Large (up to 1000kg)',
        'features': <String>['Spacious', 'Reliable', 'Heavy-duty'],
        'imageUrl': 'https://example.com/vehicles/4wheeler.jpg',
        'isAvailable': true,
      },
    );

    await _firestore.collection('vehicles').doc('VEH004').set(
      {
        'id': 'VEH004',
        'name': '6-Wheeler',
        'type': '6-wheeler',
        'description': 'Medium truck for heavy deliveries',
        'baseFare': 500.00,
        'perKmRate': 65.00,
        'capacity': 'Extra Large (up to 3000kg)',
        'features': <String>['Heavy-duty', 'High capacity', 'Professional'],
        'imageUrl': 'https://example.com/vehicles/6wheeler.jpg',
        'isAvailable': true,
      },
    );

    await _firestore.collection('vehicles').doc('VEH005').set(
      {
        'id': 'VEH005',
        'name': 'Wingvan',
        'type': 'wingvan',
        'description': 'Large wing van for bulk deliveries',
        'baseFare': 700.00,
        'perKmRate': 80.00,
        'capacity': 'Bulk (up to 5000kg)',
        'features': <String>['Bulk capacity', 'Enclosed', 'Secure'],
        'imageUrl': 'https://example.com/vehicles/wingvan.jpg',
        'isAvailable': true,
      },
    );

    await _firestore.collection('vehicles').doc('VEH006').set(
      {
        'id': 'VEH006',
        'name': '10-Wheeler Wingvan',
        'type': '10-wheeler',
        'description': 'Extra large wing van for industrial deliveries',
        'baseFare': 1000.00,
        'perKmRate': 120.00,
        'capacity': 'Industrial (up to 10000kg)',
        'features': <String>[
          'Maximum capacity',
          'Industrial grade',
          'Heavy-duty'
        ],
        'imageUrl': 'https://example.com/vehicles/10wheeler.jpg',
        'isAvailable': true,
      },
    );

    // Sample Notifications
    await _firestore.collection('notifications').doc('NOTIF001').set(
      {
        'notificationId': 'NOTIF001',
        'recipientId': '+6391234567',
        'recipientType': 'customer',
        'title': 'Booking Confirmed',
        'message':
            'Your booking BK001 has been confirmed. Your driver is on the way!',
        'type': 'booking',
        'isUnread': true,
        'bookingId': 'BK001',
        'amount': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'data': {
          'driverName': 'Pedro Reyes',
          'vehicleType': '4-Wheeler',
          'vehiclePlate': 'ABC 1234',
        },
      },
    );

    await _firestore.collection('notifications').doc('NOTIF002').set(
      {
        'notificationId': 'NOTIF002',
        'recipientId': 'RIDER001',
        'recipientType': 'rider',
        'title': 'New Delivery Request',
        'message': 'You have a new delivery request from Juan Dela Cruz.',
        'type': 'delivery_request',
        'isUnread': true,
        'bookingId': 'BK001',
        'amount': 850.00,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'data': {
          'pickupAddress': '123 Main Street, Brgy. Poblacion, Makati City',
          'dropoffAddress': '456 Corporate Ave, BGC, Taguig City',
          'fare': 850.00,
        },
      },
    );

    // Sample Email Notifications
    await _firestore.collection('email_notifications').doc('EMAIL001').set(
      {
        'to': 'juan.delacruz@example.com',
        'subject': 'Welcome to CitiMovers!',
        'htmlBody':
            '<h1>Welcome to CitiMovers!</h1><p>Thank you for joining us. Your account has been verified.</p>',
        'textBody': 'Welcome to CitiMovers! Your account has been verified.',
        'templateId': 'welcome',
        'templateData': {'name': 'Juan'},
        'type': 'verification',
        'referenceId': 'USER001',
        'isSent': true,
        'sentAt': DateTime.now().millisecondsSinceEpoch,
        'errorMessage': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Sample Rider Settings
    await _firestore.collection('rider_settings').doc('RIDER001').set(
      {
        'riderId': 'RIDER001',
        'pushNotifications': true,
        'emailNotifications': true,
        'smsNotifications': true,
        'soundEffects': true,
        'vibration': true,
        'locationServices': true,
        'autoAcceptDeliveries': false,
        'language': 'English',
        'theme': 'Light',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    await _firestore.collection('rider_settings').doc('RIDER002').set(
      {
        'riderId': 'RIDER002',
        'pushNotifications': true,
        'emailNotifications': false,
        'smsNotifications': true,
        'soundEffects': false,
        'vibration': true,
        'locationServices': true,
        'autoAcceptDeliveries': true,
        'language': 'Filipino',
        'theme': 'Dark',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Sample Booking
    await _firestore.collection('bookings').doc('BK001').set(
      {
        'bookingId': 'BK001',
        'customerId': '+6391234567',
        'driverId': 'RIDER001',
        'pickupLocation': {
          'id': 'LOC001',
          'label': 'Pickup Location',
          'address': '123 Main Street, Brgy. Poblacion, Makati City',
          'latitude': 14.5607,
          'longitude': 121.0198,
          'city': 'Makati',
          'province': 'Metro Manila',
          'country': 'Philippines',
          'isFavorite': false,
        },
        'dropoffLocation': {
          'id': 'LOC002',
          'label': 'Dropoff Location',
          'address': '456 Corporate Ave, BGC, Taguig City',
          'latitude': 14.5116,
          'longitude': 121.0428,
          'city': 'Taguig',
          'province': 'Rizal',
          'country': 'Philippines',
          'isFavorite': false,
        },
        'vehicle': {
          'id': 'VEH003',
          'name': '4-Wheeler',
          'type': '4-wheeler',
          'description': 'Light truck for larger deliveries',
          'baseFare': 300.00,
          'perKmRate': 45.00,
          'capacity': 'Large (up to 1000kg)',
          'features': <String>['Spacious', 'Reliable', 'Heavy-duty'],
          'imageUrl': 'https://example.com/vehicles/4wheeler.jpg',
          'isAvailable': true,
        },
        'bookingType': 'on_demand',
        'scheduledDateTime': null,
        'distance': 15.5,
        'estimatedFare': 697.50,
        'finalFare': 750.00,
        'status': 'pending',
        'paymentMethod': 'Cash',
        'notes': 'Please handle with care',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'completedAt': null,
        'cancellationReason': null,
        'insuranceCoverage': 5000.00,
        'tipAmount': null,
        'demurrageCharges': null,
        'loadingStartTime': null,
        'loadingEndTime': null,
        'unloadingStartTime': null,
        'unloadingEndTime': null,
      },
    );

    // Sample Payment
    await _firestore.collection('payments').doc('PAY001').set(
      {
        'paymentId': 'PAY001',
        'bookingId': 'BK001',
        'payerId': '+6391234567',
        'payeeId': 'RIDER001',
        'amount': 750.00,
        'method': 'gcash',
        'status': 'completed',
        'createdAt': now,
        'updatedAt': now,
        'metadata': {
          'transactionId': 'TXN002',
          'referenceNumber': 'GCASH-123456',
        },
      },
    );
  }
}
