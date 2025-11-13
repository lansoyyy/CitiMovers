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
    _startRiderSearch();
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

  void _startRiderSearch() {
    // Simulate finding a rider after 5 seconds
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isSearchingForRider = false;
          _riderFound = true;
        });
        _addDriverMarker();
        _drawRoute();
        _startPickup();
      }
    });
  }

  void _startPickup() {
    // Simulate finding a rider after 5 seconds
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isSearchingForRider = false;
          _riderFound = false;
          hasPickedUp = true;
        });
      }
    });
  }

  void _addDriverMarker() {
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Driver Location'),
      ),
    );
  }

  Future<void> _drawRoute() async {
    // Hardcoded route points (simulating a route from driver to pickup to dropoff)
    List<LatLng> polylineCoordinates = [
      _driverLocation,
      const LatLng(7.0680, 125.6100),
      const LatLng(7.0700, 125.6115),
      _pickupLocation,
      const LatLng(7.0750, 125.6140),
      const LatLng(7.0800, 125.6170),
      const LatLng(7.0850, 125.6185),
      _dropoffLocation,
    ];

    // Create polyline
    Polyline polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.green,
      points: polylineCoordinates,
      width: 5,
    );

    setState(() {
      _polylines.add(polyline);
    });

    // Animate camera to show the entire route
    if (_mapController != null) {
      LatLngBounds bounds = _calculateBounds(polylineCoordinates);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
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

          // Back button
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: _isSearchingForRider
                ? 0.35
                : hasPickedUp
                    ? 0.45
                    : 0.5,
            minChildSize: 0.3,
            maxChildSize: hasPickedUp ? 0.45 : 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xff00B04E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: hasPickedUp ? 65 : 0),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Handle bar
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

                            // Content based on state
                            if (_isSearchingForRider) ...[
                              _buildSearchingContent(),
                            ] else if (_riderFound) ...[
                              _buildRiderFoundContent(),
                            ] else if (hasPickedUp) ...[
                              _buildPickedUpContent(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Visibility(
                      visible: hasPickedUp,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Party Platters for 15+',
                                  style: TextStyle(
                                      color: Colors.white, fontFamily: 'Bold'),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ad:',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Bold',
                                          fontSize: 13),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'GradFood',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Regular',
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Image.asset(
                                  'assets/images/pizza.png',
                                  width: 50,
                                  height: 50,
                                ),
                              ],
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

  Widget _buildSearchingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Looking for a ride',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                fontWeight: FontWeight.bold,
              ),
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
        const SizedBox(height: 10),

        // Progress indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: 100,
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                ),
              ),
            ),
            SizedBox(
              width: 5,
            ),
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup location
              _buildLocationRow(
                Icons.circle,
                Colors.blue,
                'Blk 6 Lot 31 Mexico Ave, Dona Asuncio...',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.circle, color: Colors.grey[300], size: 6),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 5),
                child: Icon(Icons.circle, color: Colors.grey[300], size: 6),
              ),
              // Dropoff location
              _buildLocationRow(
                Icons.location_on_rounded,
                Colors.red,
                'Gaisano Mall of Davao',
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Payment method
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment method
              _buildInfoCard(
                icon: Icons.credit_card,
                iconColor: Colors.blue,
                title: '4126',
                subtitle: '',
              ),
              const SizedBox(height: 5),

              // Ride type
              _buildInfoCard(
                icon: Icons.person_outline_sharp,
                iconColor: Colors.teal,
                title: 'Personal',
              ),
              Divider(
                color: Colors.grey,
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total fare',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Medium',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    '₱225.00',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // Total fare

        const SizedBox(height: 20),

        // Cancel button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Cancel Booking',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
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
