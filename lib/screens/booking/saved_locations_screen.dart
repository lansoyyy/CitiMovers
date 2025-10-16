import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/ui_helpers.dart';
import '../../models/location_model.dart';
import '../../services/location_service.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final LocationService _locationService = LocationService();
  List<LocationModel> _savedLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedLocations();
  }

  Future<void> _loadSavedLocations() async {
    setState(() => _isLoading = true);

    final locations = await _locationService.getSavedLocations();

    setState(() {
      _savedLocations = locations;
      _isLoading = false;
    });
  }

  Future<void> _deleteLocation(LocationModel location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "${location.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _locationService.deleteSavedLocation(location.id!);
      if (success) {
        UIHelpers.showSuccessToast('Location deleted');
        _loadSavedLocations();
      } else {
        UIHelpers.showErrorToast('Failed to delete location');
      }
    }
  }

  Future<void> _editLocation(LocationModel location) async {
    final labelController = TextEditingController(text: location.label);

    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(
          controller: labelController,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'e.g., Home, Work, Office',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, labelController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty) {
      final updatedLocation = location.copyWith(label: newLabel);
      final success = await _locationService.updateSavedLocation(updatedLocation);

      if (success) {
        UIHelpers.showSuccessToast('Label updated');
        _loadSavedLocations();
      } else {
        UIHelpers.showErrorToast('Failed to update label');
      }
    }
  }

  void _selectLocation(LocationModel location) {
    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Saved Locations'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedLocations.isEmpty
              ? _buildEmptyState()
              : _buildLocationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Saved Locations',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Save your frequently used locations for quick access',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedLocations.length,
      itemBuilder: (context, index) {
        final location = _savedLocations[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getIconColor(location.label).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForLabel(location.label),
                color: _getIconColor(location.label),
                size: 28,
              ),
            ),
            title: Text(
              location.label ?? 'Saved Location',
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                location.address,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Regular',
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _editLocation(location);
                } else if (value == 'delete') {
                  _deleteLocation(location);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Label'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: AppColors.primaryRed),
                      SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: TextStyle(color: AppColors.primaryRed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _selectLocation(location),
          ),
        );
      },
    );
  }

  IconData _getIconForLabel(String? label) {
    if (label == null) return Icons.location_on;

    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('home')) return Icons.home;
    if (lowerLabel.contains('work') || lowerLabel.contains('office')) {
      return Icons.work;
    }
    if (lowerLabel.contains('school')) return Icons.school;
    if (lowerLabel.contains('gym')) return Icons.fitness_center;
    if (lowerLabel.contains('mall') || lowerLabel.contains('shop')) {
      return Icons.shopping_bag;
    }

    return Icons.location_on;
  }

  Color _getIconColor(String? label) {
    if (label == null) return AppColors.primaryRed;

    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('home')) return AppColors.primaryRed;
    if (lowerLabel.contains('work') || lowerLabel.contains('office')) {
      return AppColors.primaryBlue;
    }
    if (lowerLabel.contains('school')) return Colors.orange;
    if (lowerLabel.contains('gym')) return Colors.green;
    if (lowerLabel.contains('mall') || lowerLabel.contains('shop')) {
      return Colors.purple;
    }

    return AppColors.primaryRed;
  }
}
