import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UberScreen extends StatefulWidget {
  const UberScreen({super.key});

  @override
  State<UberScreen> createState() => _UberScreenState();
}

class _UberScreenState extends State<UberScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Hardcoded locations (Davao City area based on the images)
  final LatLng _pickupLocation =
      const LatLng(7.0731, 125.6128); // Gaisano Mall of Davao
  final LatLng _dropoffLocation =
      const LatLng(7.0911, 125.6203); // Blk 6 Lot 31 Mexico Ave

  // Hardcoded driver location
  final LatLng _driverLocation = const LatLng(7.0650, 125.6080);

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    // Pickup marker
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );

    // Dropoff marker
    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off Location'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLocation,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            zoomControlsEnabled: false,
          ),

          // Top Floating Bar
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 24),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Av Miradouro 35 ',
                          style: TextStyle(
                            fontFamily: 'Bold',
                            color:
                                Color(0xFF2E8B57), // Greenish color for origin
                            fontSize: 16,
                          ),
                        ),
                        Icon(Icons.arrow_forward,
                            size: 16, color: Colors.black),
                        Text(
                          ' Home',
                          style: TextStyle(
                            fontFamily: 'Bold',
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add, size: 24),
                ],
              ),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Stack(
                children: [
                  // Main Content Container
                  Container(
                    margin: const EdgeInsets.only(
                        top: 30), // Space for the banner top part
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Scrollable List
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20,
                                160), // Bottom padding for fixed footer
                            children: [
                              _buildRideOption(
                                name: 'Bolt',
                                time: '2 min',
                                passengers: 4,
                                price: '€3.98',
                                oldPrice: '€4.98',
                                imageAsset: 'assets/images/bolt1.png',
                                tag: 'RECOMMENDED',
                              ),
                              _buildRideOption(
                                name: 'Economy',
                                time: '8 min',
                                passengers: 3,
                                price: '€3.54',
                                oldPrice: '€4.43',
                                imageAsset: 'assets/images/bolt2.png',
                                isSelected: true,
                                description: 'Affordable rides',
                              ),
                              _buildRideOption(
                                name: 'XL',
                                time: '8 min',
                                passengers: 6,
                                price: '€7.17',
                                oldPrice: '€8.96',
                                imageAsset:
                                    'assets/images/bolt3.png', // Assuming bolt3 is larger
                              ),
                              _buildRideOption(
                                name: 'Priority',
                                time: '2 min',
                                passengers: 3,
                                price: '€3.54-10.02',
                                oldPrice:
                                    '€4.42-12.52', // Guesstimate based on partial view
                                imageAsset: 'assets/images/bolt1.png',
                                isPriority: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Green Banner (Floating on top of the sheet content)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B3B24), // Dark Green
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '+ 10% cashback + 20% off ⓘ',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Medium',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Fixed Bottom Section
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Payment Info Row
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 24,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.asset(
                                    'assets/images/apple-pay-og.jpg',
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, _, __) =>
                                        const Icon(Icons.payment, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Text(
                                        'Personal ride',
                                        style: TextStyle(
                                          fontFamily: 'Bold',
                                          fontSize: 16,
                                        ),
                                      ),
                                      Icon(Icons.keyboard_arrow_down, size: 20),
                                    ],
                                  ),
                                  const Text(
                                    'Bolt balance debt: -4.90€',
                                    style: TextStyle(
                                      fontFamily: 'Regular',
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xff00B04E), // Bolt Green
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Select Economy',
                                    style: TextStyle(
                                      fontFamily: 'Bold',
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: const BoxDecoration(
                                  color: const Color(0xff00B04E), // Bolt Green
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.calendar_today,
                                      color: Colors.white),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRideOption({
    required String name,
    required String time,
    required int passengers,
    required String price,
    required String oldPrice,
    required String imageAsset,
    bool isSelected = false,
    String? tag,
    String? description,
    bool isPriority = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF0F9F4)
            : Colors.white, // Very light green background if selected
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF2E8B57), width: 2)
            : Border.all(color: Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Car Image
            Image.asset(
              imageAsset,
              width: 60,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (ctx, _, __) =>
                  const Icon(Icons.directions_car, size: 40),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Bold',
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      if (isPriority) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_double_arrow_up,
                            size: 16, color: Colors.grey),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontFamily: 'Regular',
                          fontSize: 14,
                          color:
                              isSelected ? Colors.grey[700] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      Text(
                        ' $passengers',
                        style: const TextStyle(
                          fontFamily: 'Regular',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Regular',
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (tag != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontFamily: 'Bold',
                          fontSize: 10,
                          color: Color(0xFF2E8B57),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'Bold',
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Text(
                  oldPrice,
                  style: const TextStyle(
                    fontFamily: 'Regular',
                    fontSize: 14,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
