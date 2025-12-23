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
              'type': 'string?', // 'home', 'office', 'other'
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
              'type':
                  'string', // 'booking', 'payment', 'verification', 'promotional', 'system'
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
              'language': 'string', // 'English', 'Filipino'
              'theme': 'string', // 'Light', 'Dark', 'System'
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
              'type': 'string', // 'bank', 'gcash', 'paymaya'
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
              'type': 'string', // 'top_up', 'payment', 'earning'
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

    await _firestore.collection('users').doc('_schema').set(
      {
        '__schema': true,
        'userId': '_schema',
        'name': 'SCHEMA_PLACEHOLDER',
        'phoneNumber': '',
        'email': '',
        'photoUrl': '',
        'userType': 'schema',
        'walletBalance': 0.0,
        'favoriteLocations': <String>[],
        'createdAt': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await _firestore
        .collection('users')
        .doc('_schema')
        .collection('saved_locations')
        .doc('_schema')
        .set(
      {
        '__schema': true,
        'id': '_schema',
        'label': 'SCHEMA_PLACEHOLDER',
        'address': '',
        'latitude': 0.0,
        'longitude': 0.0,
        'city': '',
        'province': '',
        'country': '',
        'isFavorite': false,
        'createdAt': now,
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('riders').doc('_schema').set(
      {
        '__schema': true,
        'riderId': '_schema',
        'name': 'SCHEMA_PLACEHOLDER',
        'phoneNumber': '',
        'email': '',
        'photoUrl': '',
        'vehicleType': 'schema',
        'vehiclePlateNumber': '',
        'vehicleModel': '',
        'vehicleColor': '',
        'status': 'schema',
        'isOnline': false,
        'rating': 0.0,
        'totalDeliveries': 0,
        'totalEarnings': 0.0,
        'currentLatitude': null,
        'currentLongitude': null,
        'documents': {
          'drivers_license': {
            'name': "Driver's License",
            'url': '',
            'status': 'not_uploaded',
            'uploadedAt': '',
          },
          'vehicle_registration': {
            'name': 'Vehicle Registration (OR/CR)',
            'url': '',
            'status': 'not_uploaded',
            'uploadedAt': '',
          },
          'nbi_clearance': {
            'name': 'NBI Clearance',
            'url': '',
            'status': 'not_uploaded',
            'uploadedAt': '',
          },
          'insurance': {
            'name': 'Insurance',
            'url': '',
            'status': 'not_uploaded',
            'uploadedAt': '',
          },
        },
        'documentsUpdatedAt': now,
        'createdAt': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('vehicles').doc('_schema').set(
      {
        '__schema': true,
        'id': '_schema',
        'name': 'SCHEMA_PLACEHOLDER',
        'type': 'SCHEMA_PLACEHOLDER',
        'description': '',
        'baseFare': 0.0,
        'perKmRate': 0.0,
        'capacity': '',
        'features': <String>[],
        'imageUrl': '',
        'isAvailable': true,
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('payments').doc('_schema').set(
      {
        '__schema': true,
        'paymentId': '_schema',
        'bookingId': '',
        'payerId': '',
        'payeeId': '',
        'amount': 0.0,
        'method': 'schema',
        'status': 'schema',
        'createdAt': now,
        'updatedAt': now,
        'metadata': <String, dynamic>{},
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('notifications').doc('_schema').set(
      {
        '__schema': true,
        'notificationId': '_schema',
        'recipientId': '',
        'recipientType': 'schema',
        'title': 'SCHEMA_PLACEHOLDER',
        'message': '',
        'type': 'schema',
        'isUnread': false,
        'bookingId': '',
        'amount': null,
        'createdAt': now,
        'data': <String, dynamic>{},
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('bookings').doc('_schema').set(
      {
        '__schema': true,
        'bookingId': '_schema',
        'customerId': '',
        'driverId': '',
        'pickupLocation': {
          'id': '',
          'label': '',
          'address': '',
          'latitude': 0.0,
          'longitude': 0.0,
          'city': '',
          'province': '',
          'country': '',
          'isFavorite': false,
        },
        'dropoffLocation': {
          'id': '',
          'label': '',
          'address': '',
          'latitude': 0.0,
          'longitude': 0.0,
          'city': '',
          'province': '',
          'country': '',
          'isFavorite': false,
        },
        'vehicle': {
          'id': '',
          'name': '',
          'type': '',
          'description': '',
          'baseFare': 0.0,
          'perKmRate': 0.0,
          'capacity': '',
          'features': <String>[],
          'imageUrl': '',
          'isAvailable': true,
        },
        'bookingType': 'now',
        'scheduledDateTime': null,
        'distance': 0.0,
        'estimatedFare': 0.0,
        'finalFare': null,
        'status': 'schema',
        'paymentMethod': '',
        'notes': '',
        'createdAt': 0,
        'completedAt': null,
        'cancellationReason': '',
      },
      SetOptions(merge: true),
    );

    // Saved Locations Schema
    await _firestore.collection('saved_locations').doc('_schema').set(
      {
        '__schema': true,
        'userId': '',
        'name': 'SCHEMA_PLACEHOLDER',
        'address': '',
        'latitude': 0.0,
        'longitude': 0.0,
        'type': null,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      },
      SetOptions(merge: true),
    );

    // Promo Banners Schema
    await _firestore.collection('promo_banners').doc('_schema').set(
      {
        '__schema': true,
        'title': 'SCHEMA_PLACEHOLDER',
        'description': '',
        'imageUrl': '',
        'actionUrl': null,
        'isActive': true,
        'startDate': null,
        'endDate': null,
        'displayOrder': 0,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      },
      SetOptions(merge: true),
    );

    // Payment Methods Schema
    await _firestore.collection('payment_methods').doc('_schema').set(
      {
        '__schema': true,
        'userId': '',
        'type': 'schema',
        'name': 'SCHEMA_PLACEHOLDER',
        'accountNumber': '',
        'accountName': '',
        'isDefault': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      },
      SetOptions(merge: true),
    );

    // Wallet Transactions Schema
    await _firestore.collection('wallet_transactions').doc('_schema').set(
      {
        '__schema': true,
        'userId': '',
        'type': 'schema',
        'amount': 0.0,
        'balance': 0.0,
        'description': '',
        'referenceId': null,
        'createdAt': DateTime.now(),
      },
      SetOptions(merge: true),
    );

    // Email Notifications Schema
    await _firestore.collection('email_notifications').doc('_schema').set(
      {
        '__schema': true,
        'to': '',
        'subject': '',
        'htmlBody': '',
        'textBody': null,
        'templateId': null,
        'templateData': null,
        'type': 'schema',
        'referenceId': null,
        'isSent': false,
        'sentAt': null,
        'errorMessage': null,
        'createdAt': DateTime.now(),
      },
      SetOptions(merge: true),
    );

    // Rider Settings Schema
    await _firestore.collection('rider_settings').doc('_schema').set(
      {
        '__schema': true,
        'riderId': '_schema',
        'pushNotifications': true,
        'emailNotifications': false,
        'smsNotifications': true,
        'soundEffects': true,
        'vibration': true,
        'locationServices': true,
        'autoAcceptDeliveries': false,
        'language': 'English',
        'theme': 'Light',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }
}
