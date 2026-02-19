import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../rider/models/rider_model.dart';

/// Crew Profile Screen - Shows driver and helpers during active delivery
/// Visible only while delivery is in progress, hidden after completion
class CrewProfileScreen extends StatefulWidget {
  final RiderModel rider;
  final bool isDeliveryCompleted;

  const CrewProfileScreen({
    super.key,
    required this.rider,
    this.isDeliveryCompleted = false,
  });

  @override
  State<CrewProfileScreen> createState() => _CrewProfileScreenState();
}

class _CrewProfileScreenState extends State<CrewProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Calculate number of tabs based on available crew
    final tabCount = _calculateTabCount();
    _tabController = TabController(length: tabCount, vsync: this);
  }

  int _calculateTabCount() {
    int count = 1; // Always have driver
    if (widget.rider.helper1 != null) count++;
    if (widget.rider.helper2 != null) count++;
    return count;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If delivery is completed, show message that profiles are hidden
    if (widget.isDeliveryCompleted) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Crew Profiles'),
          backgroundColor: AppColors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Profiles Hidden',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Crew profiles are no longer accessible after delivery completion for privacy protection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Delivery Crew',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.textPrimary),
            onPressed: () => _showLegalNotice(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryRed,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Medium',
            fontSize: 14,
          ),
          tabs: _buildTabs(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _buildTabViews(),
      ),
    );
  }

  List<Tab> _buildTabs() {
    final tabs = <Tab>[];

    // Driver tab
    tabs.add(const Tab(
      icon: Icon(Icons.drive_eta, size: 20),
      text: 'Driver',
    ));

    // Helper 1 tab
    if (widget.rider.helper1 != null) {
      tabs.add(const Tab(
        icon: Icon(Icons.person, size: 20),
        text: 'Helper 1',
      ));
    }

    // Helper 2 tab
    if (widget.rider.helper2 != null) {
      tabs.add(const Tab(
        icon: Icon(Icons.person, size: 20),
        text: 'Helper 2',
      ));
    }

    return tabs;
  }

  List<Widget> _buildTabViews() {
    final views = <Widget>[];

    // Driver view
    views.add(_buildDriverView());

    // Helper 1 view
    if (widget.rider.helper1 != null) {
      views.add(_buildHelperView(widget.rider.helper1!, 'Helper 1'));
    }

    // Helper 2 view
    if (widget.rider.helper2 != null) {
      views.add(_buildHelperView(widget.rider.helper2!, 'Helper 2'));
    }

    return views;
  }

  Widget _buildDriverView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Card with Photo
          _buildProfileCard(
            name: widget.rider.name,
            photoUrl: widget.rider.photoUrl,
            role: 'Driver',
            phone: widget.rider.phoneNumber,
          ),

          const SizedBox(height: 16),

          // Vehicle Info Card
          _buildVehicleCard(),

          const SizedBox(height: 16),

          // Documents Section
          _buildDocumentsSection(widget.rider.documents, 'Driver'),

          const SizedBox(height: 16),

          // Privacy Notice
          _buildPrivacyNotice(),
        ],
      ),
    );
  }

  Widget _buildHelperView(HelperModel helper, String role) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Card with Photo
          _buildProfileCard(
            name: helper.name,
            photoUrl: helper.photoUrl,
            role: role,
            phone: helper.phoneNumber,
          ),

          const SizedBox(height: 16),

          // Documents Section
          _buildDocumentsSection(helper.documents, role),

          const SizedBox(height: 16),

          // Privacy Notice
          _buildPrivacyNotice(),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required String name,
    String? photoUrl,
    required String role,
    String? phone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Photo (Head to shoulders visible)
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryRed.withOpacity(0.3),
                width: 2,
              ),
              color: AppColors.lightGrey,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.lightGrey,
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryRed,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: AppColors.lightGrey,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Medium',
                color: AppColors.primaryRed,
              ),
            ),
          ),

          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Medium',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Information',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Vehicle Photo
          if (widget.rider.vehiclePhotoUrl != null &&
              widget.rider.vehiclePhotoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.rider.vehiclePhotoUrl!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 150,
                    color: AppColors.lightGrey,
                    child: Icon(
                      Icons.directions_car,
                      size: 50,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Vehicle Details
          _buildInfoRow(
            icon: Icons.local_shipping,
            label: 'Vehicle Type',
            value: widget.rider.vehicleType,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.confirmation_number,
            label: 'Plate Number',
            value: widget.rider.vehiclePlateNumber ?? 'N/A',
            isHighlight: true,
          ),
          if (widget.rider.vehicleModel != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.directions_car,
              label: 'Model',
              value: widget.rider.vehicleModel!,
            ),
          ],
          if (widget.rider.vehicleColor != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.palette,
              label: 'Color',
              value: widget.rider.vehicleColor!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Regular',
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Medium',
                  color: isHighlight
                      ? AppColors.primaryRed
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(Map<String, dynamic>? documents, String role) {
    if (documents == null || documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.folder_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No documents available for $role',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 20,
                color: AppColors.primaryRed,
              ),
              const SizedBox(width: 8),
              const Text(
                'Documents',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap to view document. All documents are watermarked for security.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: documents.entries.map((entry) {
              return _buildDocumentChip(entry.key, entry.value);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentChip(String key, dynamic value) {
    String docName = key.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    String? docUrl;
    if (value is String) {
      docUrl = value;
    } else if (value is Map && value['url'] != null) {
      docUrl = value['url'] as String;
    }

    return ActionChip(
      avatar: Icon(
        Icons.description_outlined,
        size: 18,
        color: AppColors.primaryRed,
      ),
      label: Text(
        docName,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'Medium',
        ),
      ),
      backgroundColor: AppColors.primaryRed.withOpacity(0.1),
      side: BorderSide.none,
      onPressed:
          docUrl != null ? () => _showDocumentViewer(docName, docUrl!) : null,
    );
  }

  void _showDocumentViewer(String docName, String docUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DocumentViewerScreen(
          docName: docName,
          docUrl: docUrl,
          crewName: widget.rider.name,
        ),
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Notice',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These profiles are visible only during your active delivery. They will be automatically hidden once delivery is completed for privacy protection.',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Regular',
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLegalNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.gavel, color: AppColors.primaryRed),
            const SizedBox(width: 8),
            const Text('Legal Notice'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'By accessing crew profiles and documents, you agree to the following:',
                style: TextStyle(fontFamily: 'Medium'),
              ),
              SizedBox(height: 12),
              Text('• Documents are for verification purposes only'),
              Text('• Unauthorized use or reproduction is prohibited'),
              Text('• Screenshots are monitored and logged'),
              Text('• Misuse may result in legal action'),
              Text('• Access is automatically revoked after delivery'),
              SizedBox(height: 12),
              Text(
                'Crew members are fully aware that their documents (police clearance, drug test, biodata, valid ID) may be reviewed by customers during delivery for legal reference purposes.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}

/// Document Viewer Screen with watermark overlay
class _DocumentViewerScreen extends StatelessWidget {
  final String docName;
  final String docUrl;
  final String crewName;

  const _DocumentViewerScreen({
    required this.docName,
    required this.docUrl,
    required this.crewName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          docName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Document Security'),
                  content: Text(
                    'This document belongs to $crewName.\n\n'
                    '• Watermarked for security\n'
                    '• Access is logged\n'
                    '• Unauthorized use prohibited',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Document Image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                docUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade900,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load document',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ),
                  );
                },
              ),
            ),
          ),

          // Watermark Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.transparent,
                      Colors.black.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.4),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'FOR VERIFICATION ONLY',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Bold',
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            crewName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Timestamp watermark
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateTime.now().toString().substring(0, 19),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Confidential badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CONFIDENTIAL',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Bold',
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
