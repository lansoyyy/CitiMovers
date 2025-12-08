import 'dart:async';
import 'package:flutter/cupertino.dart';
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
  bool _isSearchingForRider = true;
  bool _riderFound = false;
  bool hasPickedUp = false;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
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
              return Container(
                decoration: const BoxDecoration(
                    color: const Color(0xFF0B3B24), // Dark Green
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    )),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 85, top: 5),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.add_box,
                              color: Color(0xFF2E8B57),
                            ),
                          ),
                          SizedBox(
                            width: 3,
                          ),
                          const Text(
                            '10% cashback + 20% off ⓘ',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Medium',
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Main Content Container
                    Container(
                      margin: const EdgeInsets.only(
                          top: 40), // Space for the banner top part
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          )),
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
                                borderRadius: BorderRadius.circular(0),
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

                    // Fixed Bottom Section
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Payment Info Row
                            Row(
                              children: [
                                Image.asset('assets/images/apple-pay-og.jpg',
                                    width: 28, height: 28),
                                const SizedBox(width: 20),
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
                                        Icon(Icons.keyboard_arrow_down,
                                            size: 20),
                                      ],
                                    ),
                                    const Text(
                                      'Bolt balance debt: -4.90€',
                                      style: TextStyle(
                                        fontFamily: 'Medium',
                                        color: Colors.red,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Buttons Row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2E8B57), // Green
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
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
                                      color: Color(0xFF2E8B57),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
        color: Colors.white, // Very light green background if selected
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
                          fontSize: 12,
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

  Widget _buildPickedUpContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver is on the way',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Bold',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Few drivers now. Your driver will do their best to\ncome ASAP.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Text(
              '3 min',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Bold',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal[700]!),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.teal[700]!,
                  size: 20,
                ),
                const SizedBox(width: 5),
                Text(
                  'SAFETY CENTRE',
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Bold',
                      color: Colors.teal[700]!),
                ),
                const SizedBox(width: 5),
                SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      thickness: 2,
                      color: Colors.teal[700]!,
                    )),
                const SizedBox(width: 5),
                Icon(
                  Icons.mic_none_rounded,
                  color: Colors.teal[700]!,
                  size: 20,
                ),
              ],
            )),
        const SizedBox(height: 20),

        // Driver info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[300],
                    child:
                        const Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        CupertinoIcons.car,
                        color: Colors.grey[600]!,
                        size: 40,
                      ),
                      iconSize: 22,
                    ),
                  ),
                  Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'LAQ9491',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Black • Toyota Vios 1.5 (Black)',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ronnie Alibangbang Berdin',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '• 5.0',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 3, top: 3),
                    child: Icon(Icons.star, size: 16, color: Colors.amber),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                      width: 275,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          Badge(
                            smallSize: 8,
                            child: Icon(
                              CupertinoIcons.chat_bubble,
                              color: Colors.grey[600]!,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'New message for you',
                            style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Regular',
                                color: Colors.grey[400]!),
                          ),
                        ],
                      )),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        CupertinoIcons.phone,
                        color: Colors.grey[600]!,
                      ),
                      iconSize: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRiderFoundContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arriving by 9:26PM',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Bold',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '2.41 km to go • 8 mins',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Image.asset(
              'assets/images/Screenshot 2025-11-13 110222.png',
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.directions_car,
                    size: 50, color: Colors.green);
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Payment method
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            children: [
              _buildInfoCard(
                icon: Icons.credit_card,
                iconColor: Colors.blue,
                title: '4126',
                subtitle: '',
              ),

              // Offers
              _buildInfoCard(
                icon: Icons.local_offer_outlined,
                iconColor: Colors.orange,
                title: 'Offers',
              ),

              // Ride type
              _buildInfoCard(
                icon: Icons.person,
                iconColor: Colors.green,
                title: 'Personal',
                trailing: const Icon(Icons.chevron_right),
              ),
              const SizedBox(height: 5),
              Divider(
                color: Colors.grey,
                thickness: 0.3,
                height: 1,
              ),
              const SizedBox(height: 24),

              // Current total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current total',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Medium',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'P189.00',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
        SizedBox(
          height: 20,
        ),
        // Rating section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How\'s your ride so far?',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Medium',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rate it or tip your driver.',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.only(left: 2.5, right: 2.5),
                    child: Icon(
                      Icons.star,
                      size: 45,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Driver info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[300],
                    child:
                        const Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Badge(
                        smallSize: 8,
                        child: Icon(
                          CupertinoIcons.chat_bubble,
                          color: Colors.grey[600]!,
                        ),
                      ),
                      iconSize: 22,
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        CupertinoIcons.phone,
                        color: Colors.grey[600]!,
                      ),
                      iconSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ronnie Alibangbang Berdin',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '• 5.0',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Medium',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 3, top: 3),
                    child: Icon(Icons.star, size: 16, color: Colors.amber),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'Black Toyota Vios 1.5 (Black) • LAP5207 •',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: Colors.black,
                ),
              ),
              Text(
                'GrabCar Saver',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: Colors.black,
                ),
              ),
              Text(
                'Joined Jul 2025',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Regular',
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 15),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 250,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Excellent Service',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your driver\'s service is\nexceptional and delightful.',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Regular',
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                          Spacer(),
                          Column(
                            children: [
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange[50],
                                ),
                                child: Center(
                                  child: const Text(
                                    '🏆',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Bold',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.brown[600],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '53',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Bold',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 250,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Great Person',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your driver is very\nfriendly and engaging.',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Regular',
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                          Spacer(),
                          Column(
                            children: [
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange[50],
                                ),
                                child: Center(
                                  child: const Text(
                                    '🏆',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Bold',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.brown[600],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '53',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Bold',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Service badges

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver credentials
              const Text(
                'Driver Credentials',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Bold',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your driver\'s licensing is fully validated by regulators',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'LTFRB Case Number',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Medium',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        icon == Icons.circle
            ? Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Container(
                  height: 15,
                  width: 15,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                  child: Icon(icon, color: Colors.white, size: 6),
                ),
              )
            : Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Regular',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          icon == Icons.credit_card
              ? Container(
                  padding: const EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.blue[900],
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'VISA',
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Bold',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
