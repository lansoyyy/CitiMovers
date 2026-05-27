import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../services/admin_repository.dart';
import '../../utils/dispatch_map_colocation.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/driver_map_marker.dart';
import '../../widgets/truck_plate_list_item.dart';

class DispatchBoardScreen extends StatefulWidget {
  const DispatchBoardScreen({super.key});

  @override
  State<DispatchBoardScreen> createState() => _DispatchBoardScreenState();
}

class _DispatchBoardScreenState extends State<DispatchBoardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();
  final Map<String, GlobalKey> _loggedInRiderCardKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _selectedUnitRiderCardKeys =
      <String, GlobalKey>{};
  String _searchQuery = '';
  String? _selectedBookingId;
  String? _selectedUnitName;
  String? _highlightedRiderId;
  bool _isAssigning = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _unitNameForRider(Map<String, dynamic> rider) {
    final unitName = (rider['unitName'] ?? 'Independent Units')
        .toString()
        .trim();
    return unitName.isEmpty ? 'Independent Units' : unitName;
  }

  GlobalKey _loggedInRiderCardKeyFor(String riderId) {
    return _loggedInRiderCardKeys.putIfAbsent(
      riderId,
      () => GlobalKey(debugLabel: 'dispatch-logged-in-rider-$riderId'),
    );
  }

  GlobalKey _selectedUnitRiderCardKeyFor(String riderId) {
    return _selectedUnitRiderCardKeys.putIfAbsent(
      riderId,
      () => GlobalKey(debugLabel: 'dispatch-selected-unit-rider-$riderId'),
    );
  }

  void _scrollUnitsPanelToRider(String riderId) {
    if (riderId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final targetContext =
          _loggedInRiderCardKeys[riderId]?.currentContext ??
          _selectedUnitRiderCardKeys[riderId]?.currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  Future<void> _handleMapRiderSelection({
    required Map<String, dynamic> tappedRider,
    required List<Map<String, dynamic>> liveRiders,
    required Map<String, Map<String, dynamic>> activeAssignments,
  }) async {
    final point = DispatchMapColocation.riderPoint(tappedRider);
    if (point == null) return;

    await _handleMapPointSelection(
      point: point,
      liveRiders: liveRiders,
      activeAssignments: activeAssignments,
    );
  }

  Future<void> _handleMapPointSelection({
    required LatLng point,
    required List<Map<String, dynamic>> liveRiders,
    required Map<String, Map<String, dynamic>> activeAssignments,
  }) async {
    final nearby = DispatchMapColocation.ridersNear(liveRiders, point);
    if (nearby.isEmpty) return;

    if (nearby.length == 1) {
      _selectRider(nearby.first);
      return;
    }

    final selected = await _showColocatedRidersPicker(
      nearby,
      activeAssignments: activeAssignments,
    );
    if (selected != null) {
      _selectRider(selected);
    }
  }

  Future<Map<String, dynamic>?> _showColocatedRidersPicker(
    List<Map<String, dynamic>> riders, {
    required Map<String, Map<String, dynamic>> activeAssignments,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select driver',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${riders.length} drivers are at this location. Choose one to view details.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: riders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rider = riders[index];
                      final riderId = (rider['id'] ?? '').toString();
                      final busyAssignment = activeAssignments[riderId];
                      final isBusy = busyAssignment != null;
                      final activityLabel = _activityLabel(
                        busyAssignment,
                        rider,
                      );
                      final activityColor = _statusColor(
                        (busyAssignment?['status'] ?? '').toString(),
                        isOnline: true,
                      );
                      final plate = (rider['plateNumber'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase();
                      final unitName = _unitNameForRider(rider);

                      return Material(
                        color: AdminTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () =>
                              Navigator.pop(sheetContext, rider),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AdminTheme.divider),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: activityColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.local_shipping,
                                    color: activityColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plate.isEmpty
                                            ? (rider['name'] ?? 'Driver')
                                                .toString()
                                            : plate,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${rider['name'] ?? 'Unknown'} • $unitName',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AdminTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _riderSubtitle(rider),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AdminTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  label: activityLabel,
                                  color: isBusy
                                      ? AdminTheme.statusPending
                                      : AdminTheme.statusActive,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectRider(
    Map<String, dynamic> rider, {
    bool revealInUnitsPanel = true,
  }) {
    final riderId = (rider['id'] ?? '').toString();
    if (riderId.isEmpty) return;

    setState(() {
      _highlightedRiderId = riderId;
      _selectedUnitName = _unitNameForRider(rider);
    });

    _focusMapOnRider(rider);

    if (revealInUnitsPanel) {
      _scrollUnitsPanelToRider(riderId);
    }
  }

  void _focusMapOnRider(Map<String, dynamic> rider) {
    if (rider['hasLiveLocation'] != true) return;

    final lat = rider['currentLatitude'];
    final lng = rider['currentLongitude'];
    if (lat is! num || lng is! num) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(
        LatLng(lat.toDouble(), lng.toDouble()),
        16.5,
      );
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupRidersByUnit(
    List<Map<String, dynamic>> riders,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final rider in riders) {
      final unitName = _unitNameForRider(rider);
      grouped.putIfAbsent(unitName, () => <Map<String, dynamic>>[]).add(rider);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return {
      for (final entry in entries)
        entry.key: entry.value
          ..sort((a, b) {
            final onlineCompare =
                ((b['isOnline'] == true) ? 1 : 0) -
                ((a['isOnline'] == true) ? 1 : 0);
            if (onlineCompare != 0) return onlineCompare;
            return (a['name'] ?? '').toString().toLowerCase().compareTo(
              (b['name'] ?? '').toString().toLowerCase(),
            );
          }),
    };
  }

  List<Map<String, dynamic>> _filterRiders(List<Map<String, dynamic>> riders) {
    if (_searchQuery.trim().isEmpty) return riders;
    final query = _searchQuery.toLowerCase();

    return riders.where((rider) {
      final haystack = [
        rider['name'],
        rider['plateNumber'],
        rider['vehicleType'],
        rider['unitName'],
        rider['phoneNumber'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _prioritizeHighlightedRider(
    List<Map<String, dynamic>> riders,
    String? highlightedRiderId,
  ) {
    if (highlightedRiderId == null ||
        highlightedRiderId.isEmpty ||
        riders.length < 2) {
      return riders;
    }

    final highlightedIndex = riders.indexWhere(
      (rider) => (rider['id'] ?? '').toString() == highlightedRiderId,
    );
    if (highlightedIndex <= 0) return riders;

    final reorderedRiders = List<Map<String, dynamic>>.from(riders);
    final highlightedRider = reorderedRiders.removeAt(highlightedIndex);
    reorderedRiders.insert(0, highlightedRider);
    return reorderedRiders;
  }

  Map<String, dynamic>? _findBooking(
    List<Map<String, dynamic>> bookings,
    String? bookingId,
  ) {
    if (bookingId == null || bookingId.isEmpty) return null;
    for (final booking in bookings) {
      if ((booking['id'] ?? '').toString() == bookingId) {
        return booking;
      }
    }
    return null;
  }

  Map<String, Map<String, dynamic>> _indexAssignmentsByRider(
    List<Map<String, dynamic>> bookings,
  ) {
    final indexed = <String, Map<String, dynamic>>{};
    for (final booking in bookings) {
      final riderId = (booking['driverId'] ?? booking['riderId'] ?? '')
          .toString()
          .trim();
      if (riderId.isNotEmpty) {
        indexed[riderId] = booking;
      }
    }
    return indexed;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'No timestamp';
    return DateFormat('MMM d, h:mm a').format(value);
  }

  String _bookingReference(Map<String, dynamic> booking) {
    final tripNumber = (booking['tripNumber'] ?? '').toString().trim();
    if (tripNumber.isNotEmpty) return tripNumber;

    final id = (booking['id'] ?? '').toString();
    if (id.length <= 8) return id;
    return id.substring(0, 8).toUpperCase();
  }

  String _riderSubtitle(Map<String, dynamic> rider) {
    final vehicle = (rider['vehicleType'] ?? 'Vehicle').toString().trim();
    final plate = (rider['plateNumber'] ?? '').toString().trim();
    final phone = (rider['phoneNumber'] ?? '').toString().trim();
    final parts = [
      vehicle,
      if (plate.isNotEmpty) plate,
      if (phone.isNotEmpty) phone,
    ];
    return parts.join(' • ');
  }

  bool _isLoggedInRider(Map<String, dynamic> rider) {
    return rider['isOnline'] == true;
  }

  Map<String, dynamic>? _findRider(
    List<Map<String, dynamic>> riders,
    String? riderId,
  ) {
    if (riderId == null || riderId.isEmpty) return null;
    for (final rider in riders) {
      if ((rider['id'] ?? '').toString() == riderId) {
        return rider;
      }
    }
    return null;
  }

  String? _resolveHighlightedRiderId(List<Map<String, dynamic>> riders) {
    final selected = _findRider(riders, _highlightedRiderId);
    if (selected == null) return null;
    return (selected['id'] ?? '').toString();
  }

  String? _resolveSelectedUnitName(
    Map<String, List<Map<String, dynamic>>> groupedRiders,
    List<Map<String, dynamic>> riders,
    String? highlightedRiderId,
  ) {
    if (_selectedUnitName != null &&
        groupedRiders.containsKey(_selectedUnitName)) {
      return _selectedUnitName;
    }

    final highlightedRider = _findRider(riders, highlightedRiderId);
    if (highlightedRider != null) {
      return _unitNameForRider(highlightedRider);
    }

    for (final entry in groupedRiders.entries) {
      if (entry.value.any(_isLoggedInRider)) {
        return entry.key;
      }
    }

    if (groupedRiders.isEmpty) return null;
    return groupedRiders.keys.first;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Assigned';
      case 'arrived_at_pickup':
        return 'At Pickup';
      case 'loading':
        return 'Loading';
      case 'loading_complete':
        return 'Loaded';
      case 'in_transit':
        return 'In Transit';
      case 'arrived_at_dropoff':
        return 'At Drop-off';
      case 'unloading':
        return 'Unloading';
      case 'unloading_complete':
        return 'Unloading Complete';
      case 'pending':
        return 'Pending';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status, {required bool isOnline}) {
    switch (status) {
      case 'arrived_at_pickup':
      case 'loading':
      case 'loading_complete':
      case 'arrived_at_dropoff':
      case 'unloading':
      case 'unloading_complete':
        return AdminTheme.statusPending;
      case 'in_transit':
        return AdminTheme.primary;
      case 'accepted':
        return AdminTheme.statusActive;
      default:
        return isOnline ? AdminTheme.statusActive : AdminTheme.textSecondary;
    }
  }

  String _activityLabel(
    Map<String, dynamic>? booking,
    Map<String, dynamic> rider,
  ) {
    if (booking == null) {
      return _isLoggedInRider(rider) ? 'Waiting Dispatch' : 'Offline';
    }
    return _statusLabel((booking['status'] ?? 'pending').toString());
  }

  String _formatLocation(Map<String, dynamic> rider) {
    final address = (rider['locationAddress'] ?? '').toString().trim();
    if (address.isNotEmpty) return address;

    final lat = rider['currentLatitude'];
    final lng = rider['currentLongitude'];
    if (lat is num && lng is num) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }

    return 'No live location yet';
  }

  String _formatSelectedUnitOverlay(Map<String, dynamic> rider) {
    final plate = (rider['plateNumber'] ?? '').toString().trim().toUpperCase();
    final location = _formatLocation(rider);
    if (plate.isEmpty) return location;
    return '$plate • $location';
  }

  List<Marker> _buildDriverMapMarkers({
    required List<Map<String, dynamic>> liveRiders,
    required Map<String, Map<String, dynamic>> activeAssignments,
    required String? highlightedRiderId,
  }) {
    final orderedRiders = List<Map<String, dynamic>>.from(liveRiders);
    if (highlightedRiderId != null) {
      orderedRiders.sort((a, b) {
        final aId = (a['id'] ?? '').toString();
        final bId = (b['id'] ?? '').toString();
        if (aId == highlightedRiderId && bId != highlightedRiderId) return 1;
        if (bId == highlightedRiderId && aId != highlightedRiderId) return -1;
        return 0;
      });
    }

    return orderedRiders.map((rider) {
      final riderId = (rider['id'] ?? '').toString();
      final busyAssignment = activeAssignments[riderId];
      final isBusy = busyAssignment != null;
      final isOnline = rider['isOnline'] == true;
      final isHighlighted = riderId == highlightedRiderId;
      final plate = (rider['plateNumber'] ?? '').toString();
      final markerColor = isHighlighted
          ? AdminTheme.primary
          : isBusy
          ? AdminTheme.statusPending
          : isOnline
          ? AdminTheme.statusActive
          : AdminTheme.textSecondary;

      return Marker(
        width: isHighlighted ? 88 : 30,
        height: isHighlighted ? 62 : 30,
        alignment: Alignment.bottomCenter,
        point: LatLng(
          (rider['currentLatitude'] as num).toDouble(),
          (rider['currentLongitude'] as num).toDouble(),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _handleMapRiderSelection(
              tappedRider: rider,
              liveRiders: liveRiders,
              activeAssignments: activeAssignments,
            ),
            child: DriverMapMarker(
              plateNumber: plate,
              markerColor: markerColor,
              isSelected: isHighlighted,
            ),
          ),
        ),
      );
    }).toList();
  }

  LatLng _resolveMapCenter(List<Map<String, dynamic>> riders) {
    final located = riders
        .where((rider) => rider['hasLiveLocation'] == true)
        .toList();
    if (located.isEmpty) {
      return const LatLng(14.5995, 120.9842);
    }

    double latSum = 0;
    double lngSum = 0;
    for (final rider in located) {
      latSum += (rider['currentLatitude'] as num).toDouble();
      lngSum += (rider['currentLongitude'] as num).toDouble();
    }

    return LatLng(latSum / located.length, lngSum / located.length);
  }

  Future<bool> _assignBookingToRider(
    Map<String, dynamic> booking,
    Map<String, dynamic> rider,
  ) async {
    if (_isAssigning) return false;

    final reasonCtrl = TextEditingController(
      text: 'Dispatched from the admin dispatch board.',
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? dialogError;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Assign Unit'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign ${rider['name'] ?? 'this rider'} to trip ${_bookingReference(booking)}?',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _riderSubtitle(rider),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    onChanged: (_) {
                      if (dialogError != null &&
                          reasonCtrl.text.trim().isNotEmpty) {
                        setDialogState(() => dialogError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Dispatch note (required)',
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final trimmedReason = reasonCtrl.text.trim();
                  if (trimmedReason.isEmpty) {
                    setDialogState(
                      () => dialogError = 'Dispatch note is required.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, trimmedReason);
                },
                child: const Text('Assign Unit'),
              ),
            ],
          ),
        );
      },
    );
    reasonCtrl.dispose();

    if (reason == null) return false;

    setState(() => _isAssigning = true);
    try {
      await AdminRepository.assignRiderToBooking(
        bookingId: (booking['id'] ?? '').toString(),
        riderId: (rider['id'] ?? '').toString(),
        reason: reason,
      );
      if (!mounted) return false;
      _scrollUnitsPanelToRider((rider['id'] ?? '').toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trip ${_bookingReference(booking)} assigned to ${rider['name'] ?? 'the selected unit'}.',
          ),
        ),
      );
      setState(() {
        _selectedBookingId = null;
        _highlightedRiderId = (rider['id'] ?? '').toString();
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  Widget _buildTruckPlatesPanel(
    List<Map<String, dynamic>> riders,
    String? highlightedRiderId,
  ) {
    final loggedInRiders = riders.where(_isLoggedInRider).toList()
      ..sort((a, b) {
        final plateA = (a['plateNumber'] ?? '').toString().trim().toUpperCase();
        final plateB = (b['plateNumber'] ?? '').toString().trim().toUpperCase();
        if (plateA.isEmpty && plateB.isNotEmpty) return 1;
        if (plateB.isEmpty && plateA.isNotEmpty) return -1;
        return plateA.compareTo(plateB);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Logged-in Trucks',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminTheme.statusActive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${loggedInRiders.length} online',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.statusActive,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a plate to locate the truck on the map and mark it as the selected unit.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (loggedInRiders.isEmpty)
              const Expanded(
                child: EmptyState(
                  message: 'No trucks are logged in right now.',
                  icon: Icons.local_shipping_outlined,
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: loggedInRiders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rider = loggedInRiders[index];
                    final riderId = (rider['id'] ?? '').toString();
                    final plate = (rider['plateNumber'] ?? '').toString();
                    final isSelected = riderId == highlightedRiderId;

                    return TruckPlateListItem(
                      plateNumber: plate,
                      isSelected: isSelected,
                      hasLiveLocation: rider['hasLiveLocation'] == true,
                      onTap: () => _selectRider(rider),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPanel(
    List<Map<String, dynamic>> riders,
    Map<String, Map<String, dynamic>> activeAssignments,
    String? highlightedRiderId,
    Map<String, dynamic>? selectedBooking,
  ) {
    final liveRiders = riders
        .where(
          (rider) =>
              _isLoggedInRider(rider) && rider['hasLiveLocation'] == true,
        )
        .toList();
    final focusedRider = highlightedRiderId == null
        ? null
        : _findRider(liveRiders, highlightedRiderId);
    final mapCenter = focusedRider != null &&
            focusedRider['hasLiveLocation'] == true
        ? LatLng(
            (focusedRider['currentLatitude'] as num).toDouble(),
            (focusedRider['currentLongitude'] as num).toDouble(),
          )
        : _resolveMapCenter(liveRiders);
    final initialZoom = focusedRider != null ? 16.5 : 11.0;
    final mapOverlayLocation = focusedRider == null
        ? 'Select a plate to view the unit address on the map.'
        : _formatSelectedUnitOverlay(focusedRider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Logged-in Drivers Map',
              trailing: Wrap(
                spacing: 8,
                children: [
                  _LegendChip(
                    color: AdminTheme.statusActive,
                    label: 'Logged in',
                  ),
                  _LegendChip(color: AdminTheme.statusPending, label: 'Busy'),
                  _LegendChip(color: AdminTheme.primary, label: 'Selected'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All logged-in trucks appear as icons on the map. Tap a plate on the left to show its label, address, and exact location.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: liveRiders.isEmpty
                  ? const EmptyState(
                      message:
                          'No logged-in drivers are broadcasting live GPS right now.',
                      icon: Icons.location_off_outlined,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            key: ValueKey('dispatch-map-${liveRiders.length}'),
                            options: MapOptions(
                              initialCenter: mapCenter,
                              initialZoom: initialZoom,
                              onTap: (_, point) {
                                _handleMapPointSelection(
                                  point: point,
                                  liveRiders: liveRiders,
                                  activeAssignments: activeAssignments,
                                );
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.citimovers.admin_web',
                              ),
                              MarkerLayer(
                                markers: _buildDriverMapMarkers(
                                  liveRiders: liveRiders,
                                  activeAssignments: activeAssignments,
                                  highlightedRiderId: highlightedRiderId,
                                ),
                              ),
                              RichAttributionWidget(
                                attributions: const [
                                  TextSourceAttribution(
                                    'OpenStreetMap contributors',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: IgnorePointer(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: focusedRider == null
                                        ? const Color(0xCC374151)
                                        : const Color(0xCC111827),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    mapOverlayLocation,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsPanel(
    List<Map<String, dynamic>> riders,
    Map<String, Map<String, dynamic>> activeAssignments,
    Map<String, dynamic>? selectedBooking,
    String? highlightedRiderId,
    String? selectedUnitName,
  ) {
    final groupedRiders = _groupRidersByUnit(riders);
    final loggedInRiders = _prioritizeHighlightedRider(
      riders.where(_isLoggedInRider).toList(),
      highlightedRiderId,
    );
    final selectedUnitRiders = _prioritizeHighlightedRider(
      selectedUnitName != null
          ? List<Map<String, dynamic>>.from(
              groupedRiders[selectedUnitName] ?? const <Map<String, dynamic>>[],
            )
          : <Map<String, dynamic>>[],
      highlightedRiderId,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Registered Units',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AdminTheme.divider),
                ),
                child: Text(
                  '${loggedInRiders.length} logged in',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedBooking == null
                  ? 'Logged-in drivers are shown first. Select a unit to review all of its current activity, then choose a booking if you need to dispatch one.'
                  : 'Assigning trip ${_bookingReference(selectedBooking)} to a registered unit.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SearchField(
              controller: _searchCtrl,
              hint: 'Search unit, rider, plate, vehicle',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            if (groupedRiders.isEmpty)
              const Expanded(
                child: EmptyState(
                  message:
                      'No active registered units matched the current search.',
                  icon: Icons.group_off_outlined,
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logged-in Drivers',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (loggedInRiders.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AdminTheme.divider),
                          ),
                          child: Text(
                            'No drivers are logged in right now.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                        )
                      else
                        ...loggedInRiders.map((rider) {
                          final riderId = (rider['id'] ?? '').toString();
                          final busyAssignment = activeAssignments[riderId];
                          final activityLabel = _activityLabel(
                            busyAssignment,
                            rider,
                          );
                          final activityColor = _statusColor(
                            (busyAssignment?['status'] ?? '').toString(),
                            isOnline: true,
                          );
                          final isHighlighted = riderId == highlightedRiderId;
                          final locationUpdatedAt =
                              AdminRepository.parseTimestamp(
                                rider['locationUpdatedAt'],
                              );

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _selectRider(rider),
                            child: Container(
                              key: _loggedInRiderCardKeyFor(riderId),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? AdminTheme.primary.withValues(alpha: 0.06)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isHighlighted
                                      ? AdminTheme.primary
                                      : AdminTheme.divider,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rider['name']?.toString() ??
                                                  'Unknown rider',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AdminTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${rider['unitName'] ?? 'Independent Units'} • ${_riderSubtitle(rider)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AdminTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _InfoChip(
                                        label: activityLabel,
                                        color: activityColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _formatLocation(rider),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AdminTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    locationUpdatedAt == null
                                        ? 'Waiting for GPS update'
                                        : 'Last GPS ping ${_formatDateTime(locationUpdatedAt)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AdminTheme.textSecondary,
                                    ),
                                  ),
                                  if (busyAssignment != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Trip ${_bookingReference(busyAssignment)} • ${busyAssignment['pickupAddress'] ?? 'No pickup'} → ${busyAssignment['dropoffAddress'] ?? 'No drop-off'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AdminTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      if (selectedUnitName != null &&
                          selectedUnitRiders.isNotEmpty) ...[
                        Text(
                          'Selected Unit Activity',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AdminTheme.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedUnitName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AdminTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _InfoChip(
                                    label:
                                        '${selectedUnitRiders.where(_isLoggedInRider).length}/${selectedUnitRiders.length} logged in',
                                    color: AdminTheme.statusActive,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...selectedUnitRiders.map((rider) {
                                final riderId = (rider['id'] ?? '').toString();
                                final activityBooking =
                                    activeAssignments[riderId];
                                final isHighlighted =
                                    riderId == highlightedRiderId;
                                final activityLabel = _activityLabel(
                                  activityBooking,
                                  rider,
                                );
                                final canAssign =
                                    selectedBooking != null &&
                                    activityBooking == null &&
                                    !_isAssigning;
                                final activityColor = _statusColor(
                                  (activityBooking?['status'] ?? '').toString(),
                                  isOnline: rider['isOnline'] == true,
                                );
                                final locationUpdatedAt =
                                    AdminRepository.parseTimestamp(
                                      rider['locationUpdatedAt'],
                                    );

                                return Container(
                                  key: _selectedUnitRiderCardKeyFor(riderId),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isHighlighted
                                        ? AdminTheme.primary.withValues(
                                            alpha: 0.06,
                                          )
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isHighlighted
                                          ? AdminTheme.primary
                                          : AdminTheme.divider,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              rider['name']?.toString() ??
                                                  'Unknown rider',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AdminTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          _InfoChip(
                                            label: activityLabel,
                                            color: activityColor,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _riderSubtitle(rider),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AdminTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _formatLocation(rider),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        locationUpdatedAt == null
                                            ? 'Waiting for GPS update'
                                            : 'Last GPS ping ${_formatDateTime(locationUpdatedAt)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AdminTheme.textSecondary,
                                        ),
                                      ),
                                      if (activityBooking != null) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          'Trip ${_bookingReference(activityBooking)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AdminTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${activityBooking['pickupAddress'] ?? 'No pickup'} → ${activityBooking['dropoffAddress'] ?? 'No drop-off'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AdminTheme.textSecondary,
                                          ),
                                        ),
                                      ] else if (selectedBooking != null) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          'Available for trip ${_bookingReference(selectedBooking)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AdminTheme.statusActive,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed: canAssign
                                              ? () => _assignBookingToRider(
                                                  selectedBooking,
                                                  rider,
                                                )
                                              : null,
                                          icon: const Icon(
                                            Icons.assignment_turned_in_outlined,
                                          ),
                                          label: Text(
                                            selectedBooking == null
                                                ? 'Select Booking'
                                                : activityBooking != null
                                                ? 'Busy on Current Trip'
                                                : _isAssigning
                                                ? 'Assigning...'
                                                : 'Assign to Trip',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'All Registered Units',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...groupedRiders.entries.map((entry) {
                        final unitRiders = entry.value;
                        final onlineCount = unitRiders
                            .where(_isLoggedInRider)
                            .length;
                        final isSelectedUnit = entry.key == selectedUnitName;

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() {
                            _selectedUnitName = entry.key;
                            final preferredRider = unitRiders.firstWhere(
                              (rider) => _isLoggedInRider(rider),
                              orElse: () => unitRiders.first,
                            );
                            _highlightedRiderId = (preferredRider['id'] ?? '')
                                .toString();
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelectedUnit
                                  ? AdminTheme.primary.withValues(alpha: 0.07)
                                  : AdminTheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelectedUnit
                                    ? AdminTheme.primary
                                    : AdminTheme.divider,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${unitRiders.length} riders • $onlineCount logged in',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AdminTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AdminTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminRepository.streamDispatchableRiders(),
      builder: (context, ridersSnapshot) {
        final riders = _filterRiders(
          ridersSnapshot.data ?? const <Map<String, dynamic>>[],
        );
        final groupedRiders = _groupRidersByUnit(riders);
        final highlightedRiderId = _resolveHighlightedRiderId(riders);
        final selectedUnitName = _resolveSelectedUnitName(
          groupedRiders,
          riders,
          highlightedRiderId,
        );

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminRepository.streamActiveAssignedBookings(),
          builder: (context, activeAssignmentsSnapshot) {
            final activeAssignments = _indexAssignmentsByRider(
              activeAssignmentsSnapshot.data ?? const <Map<String, dynamic>>[],
            );

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: AdminRepository.streamDispatchQueue(),
              builder: (context, queueSnapshot) {
                final queue =
                    queueSnapshot.data ?? const <Map<String, dynamic>>[];
                final selectedBooking =
                    _findBooking(queue, _selectedBookingId) ??
                    (queue.isNotEmpty ? queue.first : null);
                final onlineCount = riders.where(_isLoggedInRider).length;
                final withGpsCount = riders
                    .where(
                      (rider) =>
                          _isLoggedInRider(rider) &&
                          rider['hasLiveLocation'] == true,
                    )
                    .length;

                if (ridersSnapshot.connectionState == ConnectionState.waiting &&
                    activeAssignmentsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    queueSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1380;
                      final truckPlatesPanel = _buildTruckPlatesPanel(
                        riders,
                        highlightedRiderId,
                      );
                      final mapPanel = _buildMapPanel(
                        riders,
                        activeAssignments,
                        highlightedRiderId,
                        selectedBooking,
                      );
                      final unitsPanel = _buildUnitsPanel(
                        riders,
                        activeAssignments,
                        selectedBooking,
                        highlightedRiderId,
                        selectedUnitName,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Coordinator Dispatch',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              _SummaryPill(
                                label: '${queue.length} waiting dispatch',
                                color: AdminTheme.statusPending,
                              ),
                              _SummaryPill(
                                label: '$onlineCount logged in',
                                color: AdminTheme.statusActive,
                              ),
                              _SummaryPill(
                                label: '$withGpsCount sharing GPS',
                                color: AdminTheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a truck plate to locate it on the map, then assign waiting bookings from the units panel.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 360, child: truckPlatesPanel),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 6, child: mapPanel),
                                      const SizedBox(width: 16),
                                      SizedBox(width: 400, child: unitsPanel),
                                    ],
                                  )
                                : ListView(
                                    children: [
                                      SizedBox(height: 340, child: truckPlatesPanel),
                                      const SizedBox(height: 16),
                                      SizedBox(height: 460, child: mapPanel),
                                      const SizedBox(height: 16),
                                      SizedBox(height: 620, child: unitsPanel),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
