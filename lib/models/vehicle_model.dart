/// Vehicle Model for CitiMovers
/// Represents different vehicle types available for booking
class VehicleModel {
  final String id;
  final String name;
  final String
      type; // 'Sedan', 'AUV', '4-Wheeler Closed Van', '6-Wheeler Closed Van', '6-Wheeler Forward Wingvan', '10-Wheeler Wingvan', '20-Footer Trailer', '40-Footer Trailer'
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
        id: 'sedan_001',
        name: 'Sedan',
        type: 'Sedan',
        description: 'Ideal for small cargo and document deliveries',
        baseFare: 150,
        perKmRate: 12,
        capacity: 'Up to 200 kg',
        features: [
          'Small packages',
          'Documents',
          'City delivery',
          'Air-conditioned',
        ],
        imageUrl: 'assets/images/sedan.png',
      ),
      VehicleModel(
        id: 'auv_001',
        name: 'AUV',
        type: 'AUV',
        description: 'Perfect for medium packages and reliable deliveries',
        baseFare: 100,
        perKmRate: 15,
        capacity: 'Up to 1,000 kg',
        features: [
          'Medium items',
          'Quick delivery',
          'City-friendly',
          'Fuel efficient',
        ],
        imageUrl: 'assets/images/auv.png',
      ),
      VehicleModel(
        id: '4wheeler_001',
        name: '4-Wheeler Closed Van',
        type: '4-Wheeler Closed Van',
        description: 'Ideal for standard deliveries and medium-sized cargo',
        baseFare: 150,
        perKmRate: 20,
        first100kmRate: 20,
        after100kmRate: 15,
        minimumFare100km: 2000,
        capacity: 'Up to 2,000 kg',
        features: [
          'Medium cargo',
          'Enclosed van',
          'Reliable',
          'Air-conditioned',
        ],
        imageUrl: 'assets/images/4wheeler.png',
      ),
      VehicleModel(
        id: '6wheeler_001',
        name: '6-Wheeler Closed Van',
        type: '6-Wheeler Closed Van',
        description: 'Great for large cargo and commercial deliveries',
        baseFare: 300,
        perKmRate: 35,
        first100kmRate: 35,
        after100kmRate: 30,
        minimumFare100km: 3500,
        capacity: 'Up to 3,000 kg',
        features: [
          'Large cargo',
          'Commercial delivery',
          'Enclosed van',
          'Professional drivers',
        ],
        imageUrl: 'assets/images/6wheeler.png',
      ),
      VehicleModel(
        id: 'wingvan_001',
        name: '6-Wheeler Forward Wingvan',
        type: '6-Wheeler Forward Wingvan',
        description: 'Perfect for bulk deliveries with side-opening wings',
        baseFare: 500,
        perKmRate: 50,
        capacity: 'Up to 7,000 kg',
        features: [
          'Bulk delivery',
          'Wing doors',
          'Easy loading',
          'Helper available',
        ],
        imageUrl: 'assets/images/wingvan.png',
      ),
      VehicleModel(
        id: '10wheeler_wingvan_001',
        name: '10-Wheeler Wingvan',
        type: '10-Wheeler Wingvan',
        description: 'Heavy-duty transport for large cargo and bulk deliveries',
        baseFare: 0,
        perKmRate: 0,
        first100kmRate: 195, // distanceKm × 3/2 × ₱130/L
        after100kmRate: 195,
        minimumFare100km: 19500, // min at 100km
        capacity: 'Up to 12,000 kg',
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
      VehicleModel(
        id: 'trailer_20ft_001',
        name: '20-Footer Trailer',
        type: '20-Footer Trailer',
        description: 'Heavy-duty 20-foot trailer for industrial and bulk cargo',
        baseFare: 0,
        perKmRate: 156, // distanceKm × 3/2.5 × ₱130/L
        first100kmRate: 156,
        after100kmRate: 156,
        minimumFare100km: 15600, // min at 100km
        capacity: 'Up to 20,000 kg',
        features: [
          'Industrial cargo',
          'Long distance',
          'Heavy-duty',
          'Secure transport',
        ],
        imageUrl: 'assets/images/trailer.png',
      ),
      VehicleModel(
        id: 'trailer_40ft_001',
        name: '40-Footer Trailer',
        type: '40-Footer Trailer',
        description: 'Maximum capacity 40-foot trailer for the heaviest loads',
        baseFare: 0,
        perKmRate: 208, // distanceKm × 4/2.5 × ₱130/L
        first100kmRate: 208,
        after100kmRate: 208,
        minimumFare100km: 20800, // min at 100km
        capacity: 'Up to 32,000 kg',
        features: [
          'Maximum capacity',
          'Industrial grade',
          'Long distance',
          'Heavy-duty',
        ],
        imageUrl: 'assets/images/trailer.png',
      ),
    ];
  }

  @override
  String toString() {
    return 'VehicleModel(type: $type, baseFare: $baseFare, perKm: $perKmRate)';
  }
}
