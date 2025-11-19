import 'dart:async';
import 'dart:io';
import 'package:citimovers/rider/models/delivery_request_model.dart';
import 'package:citimovers/utils/app_colors.dart';
import 'package:citimovers/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class RiderDeliveryProgressScreen extends StatefulWidget {
  final DeliveryRequest request;

  const RiderDeliveryProgressScreen({
    super.key,
    required this.request,
  });

  @override
  State<RiderDeliveryProgressScreen> createState() =>
      _RiderDeliveryProgressScreenState();
}

enum DeliveryStep {
  headingToWarehouse,
  loading, // Includes "Arrived" -> "Start Loading" -> "Finish Loading"
  delivering,
  unloading, // Includes "Arrived" -> "Start Unloading" -> "Finish Unloading"
  receiving,
  completed
}

enum LoadingSubStep { arrived, startLoading, finishLoading }

enum UnloadingSubStep { arrived, startUnloading, finishUnloading }

class _RiderDeliveryProgressScreenState
    extends State<RiderDeliveryProgressScreen> with TickerProviderStateMixin {
  DeliveryStep _currentStep = DeliveryStep.headingToWarehouse;
  LoadingSubStep? _loadingSubStep;
  UnloadingSubStep? _unloadingSubStep;

  // Demurrage Tracking (Loading)
  Timer? _loadingTimer;
  Duration _loadingDuration = Duration.zero;
  double _loadingDemurrageFee = 0.0;
  File? _startLoadingPhoto;
  File? _finishLoadingPhoto;
  bool _loadingDemurrageStarted = false;

  // Demurrage Tracking (Unloading)
  Timer? _unloadingTimer;
  Duration _unloadingDuration = Duration.zero;
  double _unloadingDemurrageFee = 0.0;
  File? _startUnloadingPhoto;
  File? _finishUnloadingPhoto;
  bool _unloadingDemurrageStarted = false;

  // Geofencing
  bool _isWithinGeofence = true;
  String _geofenceStatus = 'Within delivery area';

  // Receiving
  final _receiverNameController = TextEditingController();
  File? _idPhoto;
  List<Offset?> _signaturePoints = [];
  bool _isSignatureEmpty = true;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _unloadingTimer?.cancel();
    _receiverNameController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  double get _baseFare {
    // Parse "P150" -> 150.0
    final fareString = widget.request.fare.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(fareString) ?? 0.0;
  }

  double get _totalDemurrageFee =>
      _loadingDemurrageFee + _unloadingDemurrageFee;
  double get _totalEarnings => _baseFare + _totalDemurrageFee;

  final ImagePicker _picker = ImagePicker();

  // Mock Coordinates (In a real app, these would come from the model or geocoding)
  static const LatLng _manila = LatLng(14.5995, 120.9842);
  static const LatLng _pickup = LatLng(14.5547, 121.0244); // Makati
  static const LatLng _dropoff = LatLng(14.5355, 120.9847); // Pasay

  Set<Marker> _createMarkers(LatLng position, String id, String title) {
    return {
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Set<Marker> _createRouteMarkers() {
    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoff,
        infoWindow: const InfoWindow(title: 'Dropoff'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  // --- Actions ---

  void _arrivedAtWarehouse() {
    setState(() {
      _currentStep = DeliveryStep.loading;
      _loadingSubStep = LoadingSubStep.arrived;
      _loadingDemurrageStarted = true;
      _startLoadingTimer();
    });
    UIHelpers.showSuccessToast(
        'Arrived at warehouse! Demurrage timer started.');
  }

  void _startLoadingTimer() {
    _loadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _loadingDuration += const Duration(seconds: 1);
        if (_loadingDemurrageStarted) {
          _calculateLoadingFee();
        }
      });
    });
  }

  void _calculateLoadingFee() {
    // "Every 4 hours - 25% of the delivery fare"
    int blocks = _loadingDuration.inHours ~/ 4;
    if (blocks > 0) {
      _loadingDemurrageFee = blocks * 0.25 * _baseFare;
    } else {
      _loadingDemurrageFee = 0.0;
    }
  }

  void _startLoadingPhotoProcess() {
    setState(() {
      _loadingSubStep = LoadingSubStep.startLoading;
    });
  }

  void _finishLoadingPhotoProcess() {
    setState(() {
      _loadingSubStep = LoadingSubStep.finishLoading;
    });
  }

  Future<void> _takePhoto(Function(File) onPicked, String photoType) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        onPicked(File(image.path));
      });
      UIHelpers.showSuccessToast('$photoType photo captured successfully!');

      // Update sub-steps based on photo taken
      if (onPicked == (file) => _startLoadingPhoto = file) {
        _startLoadingPhotoProcess();
      } else if (onPicked == (file) => _finishLoadingPhoto = file) {
        _finishLoadingPhotoProcess();
      }
    }
  }

  void _finishLoading() {
    if (_startLoadingPhoto == null || _finishLoadingPhoto == null) {
      UIHelpers.showInfoToast('Please take both photos to finish loading.');
      return;
    }
    _loadingTimer?.cancel();
    _loadingDemurrageStarted = false;
    setState(() {
      _currentStep = DeliveryStep.delivering;
      _loadingSubStep = null;
    });
    UIHelpers.showSuccessToast('Loading completed! Ready for delivery.');
  }

  void _arrivedAtClient() {
    // Geo-fencing check
    if (!_isWithinGeofence) {
      _showGeofenceWarning();
      return;
    }

    setState(() {
      _currentStep = DeliveryStep.unloading;
      _unloadingSubStep = UnloadingSubStep.arrived;
      _unloadingDemurrageStarted = true;
      _startUnloadingTimer();
    });
    UIHelpers.showSuccessToast(
        'Arrived at destination! Demurrage timer started.');
  }

  void _showGeofenceWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Warning'),
        content: const Text(
          'You are not within the designated delivery area. Please proceed to the correct location to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startUnloadingTimer() {
    _unloadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _unloadingDuration += const Duration(seconds: 1);
        if (_unloadingDemurrageStarted) {
          _calculateUnloadingFee();
        }
      });
    });
  }

  void _calculateUnloadingFee() {
    int blocks = _unloadingDuration.inHours ~/ 4;
    if (blocks > 0) {
      _unloadingDemurrageFee = blocks * 0.25 * _baseFare;
    } else {
      _unloadingDemurrageFee = 0.0;
    }
  }

  void _startUnloadingPhotoProcess() {
    setState(() {
      _unloadingSubStep = UnloadingSubStep.startUnloading;
    });
  }

  void _finishUnloadingPhotoProcess() {
    setState(() {
      _unloadingSubStep = UnloadingSubStep.finishUnloading;
    });
  }

  void _finishUnloading() {
    if (_startUnloadingPhoto == null || _finishUnloadingPhoto == null) {
      UIHelpers.showInfoToast('Please take both photos to finish unloading.');
      return;
    }
    _unloadingTimer?.cancel();
    _unloadingDemurrageStarted = false;
    setState(() {
      _currentStep = DeliveryStep.receiving;
      _unloadingSubStep = null;
    });
    UIHelpers.showSuccessToast(
        'Unloading completed! Ready for receiver confirmation.');
  }

  void _completeDelivery() {
    if (_receiverNameController.text.isEmpty) {
      UIHelpers.showInfoToast('Please enter receiver name.');
      return;
    }
    if (_idPhoto == null) {
      UIHelpers.showInfoToast('Please take ID photo.');
      return;
    }
    if (_isSignatureEmpty) {
      UIHelpers.showInfoToast('Receiver signature is required.');
      return;
    }

    setState(() {
      _currentStep = DeliveryStep.completed;
    });

    // Send Email Logic Mock
    _sendCompletionEmails();
    UIHelpers.showSuccessToast(
        'Delivery Completed! Confirmation emails sent to Customer, Admin, and Driver.');

    // Navigate back home after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _sendCompletionEmails() {
    // Mock email sending functionality
    final now = DateTime.now();
    final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(now);

    // In a real app, these would be actual API calls
    print('Email to Customer: Delivery completed at $formattedTime');
    print('Email to Admin: Delivery #${widget.request.id} completed by rider');
    print('Email to Driver: Delivery confirmation and earnings summary');
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Delivery Progress'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(),
              ),
            ),
            if (_currentStep != DeliveryStep.completed) _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStepIcon(
              DeliveryStep.headingToWarehouse, Icons.warehouse, 'Pickup'),
          _buildStepLine(DeliveryStep.loading),
          _buildStepIcon(
              DeliveryStep.delivering, Icons.local_shipping, 'Transit'),
          _buildStepLine(DeliveryStep.unloading),
          _buildStepIcon(DeliveryStep.receiving, Icons.person_pin, 'Dropoff'),
        ],
      ),
    );
  }

  Widget _buildStepIcon(DeliveryStep step, IconData icon, String label) {
    Color color = AppColors.grey;
    if (_currentStep.index >= step.index) color = AppColors.primaryRed;
    if (_currentStep == DeliveryStep.completed) color = AppColors.success;

    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Medium',
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(DeliveryStep nextStep) {
    bool isActive = _currentStep.index >= nextStep.index;
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppColors.primaryRed : AppColors.lightGrey,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        return _buildHeadingToWarehouseView();
      case DeliveryStep.loading:
        return _buildLoadingView();
      case DeliveryStep.delivering:
        return _buildDeliveringView();
      case DeliveryStep.unloading:
        return _buildUnloadingView();
      case DeliveryStep.receiving:
        return _buildReceivingView();
      case DeliveryStep.completed:
        return _buildCompletedView();
    }
  }

  Widget _buildBottomAction() {
    String label = '';
    VoidCallback? onTap;
    Color color = AppColors.primaryRed;

    switch (_currentStep) {
      case DeliveryStep.headingToWarehouse:
        label = 'Arrived at Warehouse';
        onTap = _arrivedAtWarehouse;
        break;
      case DeliveryStep.loading:
        // Managed inside view
        return const SizedBox.shrink();
      case DeliveryStep.delivering:
        label = 'Arrived at Destination';
        onTap = _arrivedAtClient;
        break;
      case DeliveryStep.unloading:
        return const SizedBox.shrink();
      case DeliveryStep.receiving:
        label = 'Complete Delivery';
        onTap = _completeDelivery;
        color = AppColors.success;
        break;
      case DeliveryStep.completed:
        label = 'Back to Home';
        onTap = () => Navigator.pop(context);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // --- Individual State Views ---

  Widget _buildHeadingToWarehouseView() {
    return Column(
      children: [
        // Map View
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _pickup,
                zoom: 14,
              ),
              markers: _createMarkers(_pickup, 'warehouse', 'Pickup Location'),
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warehouse,
                        color: AppColors.primaryRed),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Heading to Pickup',
                          style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Distance: ${widget.request.distance}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Pickup Location',
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.request.pickupLocation,
                style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              _buildInfoCard('Navigate to the warehouse to start loading.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDemurrageTimerCard(
            'Loading Demurrage', _loadingDuration, _loadingDemurrageFee),
        const SizedBox(height: 24),
        const Text('Loading Process',
            style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Start Loading',
          _startLoadingPhoto,
          (file) => _startLoadingPhoto = file,
          photoType: 'Start Loading',
        ),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Finished Loading',
          _finishLoadingPhoto,
          (file) => _finishLoadingPhoto = file,
          photoType: 'Finished Loading',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _finishLoading,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Finish Loading',
                style: TextStyle(
                    fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveringView() {
    return Column(
      children: [
        // Map View with Route
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _manila, // Center between points approx
                zoom: 12,
              ),
              markers: _createRouteMarkers(),
              polylines: {
                const Polyline(
                  polylineId: PolylineId('route'),
                  points: [_pickup, _dropoff],
                  color: AppColors.primaryBlue,
                  width: 5,
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'On the Way',
                          style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Bold',
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Est. Time: ${widget.request.estimatedTime}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Drop-off Location',
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Bold',
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.request.deliveryLocation,
                style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Medium',
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              _buildInfoCard('Deliver the package to the client location.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnloadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDemurrageTimerCard(
            'Unloading Demurrage', _unloadingDuration, _unloadingDemurrageFee),
        const SizedBox(height: 24),
        const Text('Unloading Process',
            style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Start Unloading',
          _startUnloadingPhoto,
          (file) => _startUnloadingPhoto = file,
          photoType: 'Start Unloading',
        ),
        const SizedBox(height: 16),
        _buildPhotoStep(
          'Finished Unloading',
          _finishUnloadingPhoto,
          (file) => _finishUnloadingPhoto = file,
          photoType: 'Finished Unloading',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _finishUnloading,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Finish Unloading',
                style: TextStyle(
                    fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildReceivingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Receiver Details',
            style: TextStyle(fontSize: 18, fontFamily: 'Bold')),
        const SizedBox(height: 16),
        TextField(
          controller: _receiverNameController,
          decoration: InputDecoration(
            labelText: 'Receiver Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 24),
        _buildPhotoStep('Receiver ID', _idPhoto, (file) => _idPhoto = file,
            photoType: 'Receiver ID'),
        const SizedBox(height: 24),
        const Text('Digital Signature',
            style: TextStyle(fontSize: 16, fontFamily: 'Bold')),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lightGrey),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  // Need to find local position within the Container
                  // Using a stack key or similar is better, but here we use simple setState
                  // For simplicity in this constraint, just adding points
                  _signaturePoints.add(details.localPosition);
                  _isSignatureEmpty = false;
                });
              },
              onPanEnd: (details) => _signaturePoints.add(null),
              child: CustomPaint(
                painter: SignaturePainter(points: _signaturePoints),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: () {
                setState(() {
                  _signaturePoints.clear();
                  _isSignatureEmpty = true;
                });
              },
              child: const Text('Clear Signature')),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          const Text(
            'Delivery Completed!',
            style: TextStyle(
                fontSize: 24, fontFamily: 'Bold', color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Text('All details have been submitted.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 40),
          _buildSummaryRow('Base Fare', 'P${_baseFare.toStringAsFixed(2)}'),
          _buildSummaryRow(
              'Demurrage Fee', 'P${_totalDemurrageFee.toStringAsFixed(2)}'),
          const Divider(height: 32),
          _buildSummaryRow(
              'Total Earnings', 'P${_totalEarnings.toStringAsFixed(2)}',
              isTotal: true),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context), // Go back to Home
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Back to Home',
                  style: TextStyle(
                      fontSize: 16, fontFamily: 'Bold', color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Components ---

  Widget _buildDemurrageTimerCard(String title, Duration duration, double fee) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String timerText =
        '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Bold', color: AppColors.warning)),
              const Icon(Icons.timer, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          Text(timerText,
              style: const TextStyle(
                  fontSize: 32,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Current Fee: P${fee.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Fees apply every 4 hours (25% of fare)',
              style: TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildPhotoStep(String label, File? image, Function(File) onPicked,
      {bool isId = false, required String photoType}) {
    return GestureDetector(
      onTap: () => _takePhoto(onPicked, photoType),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGrey),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: image != null
                    ? DecorationImage(
                        image: FileImage(image), fit: BoxFit.cover)
                    : null,
              ),
              child: image == null
                  ? const Icon(Icons.camera_alt, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontFamily: 'Bold', fontSize: 14)),
                  Text(image != null ? 'Photo taken' : 'Tap to take photo',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (image != null)
              const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.primaryBlue))),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontFamily: isTotal ? 'Bold' : 'Regular',
                  color: isTotal
                      ? AppColors.textPrimary
                      : AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 20 : 14,
                  fontFamily: 'Bold',
                  color: isTotal ? AppColors.success : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
