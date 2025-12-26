/// Vehicle Model for CitiMovers
/// Represents different vehicle types available for booking
class VehicleModel {
  final String id;
  final String name;
  final String
      type; // 'AUV', 'L300', '4-Wheeler', '6-Wheeler', 'Wingvan', 'Trailer'
  final String description;
  final double baseFare;
  final double perKmRate;
  final double first100kmRate; // Rate for first 100km
  final double after100kmRate; // Rate after 100km
  final double minimumFare100km; // Minimum fare for first 100km
  final String capacity;
  final List<String> features;
  final String imageUrl;
  final bool isAvailable;

  VehicleModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.baseFare,
    required this.perKmRate,
    this.first100kmRate = 0.0,
    this.after100kmRate = 0.0,
    this.minimumFare100km = 0.0,
    required this.capacity,
    required this.features,
    required this.imageUrl,
    this.isAvailable = true,
  });

  /// Get estimated fare for a given distance
  double getEstimatedFare(double distanceKm) {
    if (first100kmRate > 0 && after100kmRate > 0 && minimumFare100km > 0) {
      // New calculation logic for vehicles with 100km minimum rates
      if (distanceKm <= 100) {
        // For first 100km, use multiplier or minimum fare (whichever is higher)
        double calculatedFare = distanceKm * first100kmRate;
        return baseFare +
            (calculatedFare > minimumFare100km
                ? calculatedFare
                : minimumFare100km);
      } else {
        // For distances over 100km
        double first100kmFare = 100 * first100kmRate;
        double remainingDistance = distanceKm - 100;
        double after100kmFare = remainingDistance * after100kmRate;
        return baseFare +
            (first100kmFare > minimumFare100km
                ? first100kmFare
                : minimumFare100km) +
            after100kmFare;
      }
    } else {
      // Original calculation for vehicles without special 100km rates
      return baseFare + (distanceKm * perKmRate);
    }
  }

  /// Get fare with peak hour surcharge
  double getFareWithSurcharge(double distanceKm, {bool isPeakHour = false}) {
    double fare = getEstimatedFare(distanceKm);
    if (isPeakHour) {
      fare *= 1.2; // 20% surcharge
    }
    return fare;
  }

  /// Create VehicleModel from Firestore document
  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      description: map['description'] as String,
      baseFare: (map['baseFare'] as num).toDouble(),
      perKmRate: (map['perKmRate'] as num).toDouble(),
      first100kmRate: (map['first100kmRate'] as num?)?.toDouble() ?? 0.0,
      after100kmRate: (map['after100kmRate'] as num?)?.toDouble() ?? 0.0,
      minimumFare100km: (map['minimumFare100km'] as num?)?.toDouble() ?? 0.0,
      capacity: map['capacity'] as String,
      features: List<String>.from(map['features'] as List),
      imageUrl: map['imageUrl'] as String,
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }

  /// Convert VehicleModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'baseFare': baseFare,
      'perKmRate': perKmRate,
      'first100kmRate': first100kmRate,
      'after100kmRate': after100kmRate,
      'minimumFare100km': minimumFare100km,
      'capacity': capacity,
      'features': features,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
    };
  }

  /// Predefined vehicle types
  static List<VehicleModel> getAvailableVehicles() {
    return [
      VehicleModel(
        id: 'auv_001',
        name: 'AUV',
        type: 'AUV',
        description: 'Perfect for small packages and quick deliveries',
        baseFare: 100,
        perKmRate: 15,
        capacity: 'Up to 50 kg',
        features: [
          'Small items',
          'Quick delivery',
          'City-friendly',
          'Fuel efficient',
        ],
        imageUrl: 'assets/images/auv.png',
      ),
      VehicleModel(
        id: 'l300_001',
        name: 'L300',
        type: 'L300',
        description: 'Versatile vehicle for medium to large deliveries',
        baseFare: 200,
        perKmRate: 25,
        first100kmRate: 25, // 25 per km for first 100km
        after100kmRate: 20, // 20 per km after 100km
        minimumFare100km: 2500, // Minimum 2500 for first 100km
        capacity: 'Up to 500 kg',
        features: [
          'Medium to large items',
          'Reliable',
          'Cost-effective for long distances',
          'Spacious cargo area',
        ],
        imageUrl: 'assets/images/l300.png',
      ),
      VehicleModel(
        id: '4wheeler_001',
        name: '4-Wheeler',
        type: '4-Wheeler',
        description: 'Ideal for standard deliveries and medium-sized items',
        baseFare: 150,
        perKmRate: 20,
        first100kmRate: 20, // 20 per km for first 100km
        after100kmRate: 15, // 15 per km after 100km
        minimumFare100km: 2000, // Minimum 2000 for first 100km
        capacity: 'Up to 200 kg',
        features: [
          'Medium items',
          'Comfortable ride',
          'Reliable',
          'Air-conditioned',
        ],
        imageUrl: 'assets/images/4wheeler.png',
      ),
      VehicleModel(
        id: '6wheeler_001',
        name: '6-Wheeler',
        type: '6-Wheeler',
        description: 'Great for large items and furniture',
        baseFare: 300,
        perKmRate: 35,
        first100kmRate: 35, // 35 per km for first 100km
        after100kmRate: 30, // 30 per km after 100km
        minimumFare100km: 3500, // Minimum 3500 for first 100km
        capacity: 'Up to 1,000 kg',
        features: [
          'Large items',
          'Furniture delivery',
          'Spacious',
          'Professional drivers',
        ],
        imageUrl: 'assets/images/6wheeler.png',
      ),
      VehicleModel(
        id: 'wingvan_001',
        name: 'Wingvan',
        type: 'Wingvan',
        description: 'Perfect for moving and bulk deliveries',
        baseFare: 500,
        perKmRate: 50,
        capacity: 'Up to 2,000 kg',
        features: [
          'Moving services',
          'Bulk delivery',
          'Extra spacious',
          'Helper available',
        ],
        imageUrl: 'assets/images/wingvan.png',
      ),
      VehicleModel(
        id: 'trailer_001',
        name: 'Trailer',
        type: 'Trailer',
        description: 'Heavy-duty transport for large cargo',
        baseFare: 800,
        perKmRate: 80,
        capacity: 'Up to 5,000 kg',
        features: [
          'Heavy cargo',
          'Long distance',
          'Industrial use',
          'Secure transport',
        ],
        imageUrl: 'assets/images/trailer.png',
      ),
      VehicleModel(
        id: '10wheeler_wingvan_001',
        name: '10-Wheeler Wingvan',
        type: '10-Wheeler Wingvan',
        description: 'Heavy-duty transport for large cargo and bulk deliveries',
        baseFare: 12000, // Minimum base fare
        perKmRate: 0, // Not used with new formula
        capacity: 'Up to 8,000 kg',
        features: [
          'Heavy cargo',
          'Bulk delivery',
          'Long distance',
          'Professional drivers',
          'Helper available',
          'Secure transport',
        ],
        imageUrl: 'assets/images/10wheeler_wingvan.png',
      ),
    ];
  }

  @override
  String toString() {
    return 'VehicleModel(type: $type, baseFare: $baseFare, perKm: $perKmRate)';
  }
}
