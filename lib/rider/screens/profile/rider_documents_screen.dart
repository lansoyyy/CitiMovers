import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';

class RiderDocumentsScreen extends StatefulWidget {
  const RiderDocumentsScreen({super.key});

  @override
  State<RiderDocumentsScreen> createState() => _RiderDocumentsScreenState();
}

class _RiderDocumentsScreenState extends State<RiderDocumentsScreen> {
  final _authService = RiderAuthService();
  bool _isUploading = false;

  final Map<String, DocumentStatus> _documents = {
    'Driver\'s License': DocumentStatus(status: 'pending', imagePath: null),
    'Vehicle Registration (OR/CR)':
        DocumentStatus(status: 'pending', imagePath: null),
    'Insurance': DocumentStatus(status: 'not_uploaded', imagePath: null),
    'NBI Clearance': DocumentStatus(status: 'not_uploaded', imagePath: null),
  };

  Future<void> _pickDocument(String documentName) async {
    if (_isUploading) return;

    final rider = _authService.currentRider;
    if (rider == null) {
      UIHelpers.showErrorToast('Please login as rider first');
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _documents[documentName] =
            DocumentStatus(status: 'pending', imagePath: image.path);
        _isUploading = true;
      });

      final success = await _authService.uploadRiderDocuments({
        documentName: image.path,
      });

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        if (!success) {
          _documents[documentName] = DocumentStatus(
            status: 'not_uploaded',
            imagePath: null,
          );
        }
      });

      if (success) {
        UIHelpers.showSuccessToast('$documentName uploaded');
      } else {
        UIHelpers.showErrorToast('Failed to upload $documentName');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not Uploaded';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.access_time;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.upload_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Documents',
          style: TextStyle(
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Upload clear photos of your documents. All documents will be reviewed within 24-48 hours.',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Regular',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Document List
              ..._documents.entries.map((entry) {
                return _DocumentCard(
                  documentName: entry.key,
                  status: entry.value.status,
                  imagePath: entry.value.imagePath,
                  statusColor: _getStatusColor(entry.value.status),
                  statusText: _getStatusText(entry.value.status),
                  statusIcon: _getStatusIcon(entry.value.status),
                  onUpload: () => _pickDocument(entry.key),
                );
              }),

              const SizedBox(height: 24),

              // Requirements Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
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
                          Icons.checklist,
                          color: AppColors.primaryRed,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Document Requirements',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _RequirementItem(
                      text: 'Photos must be clear and readable',
                    ),
                    _RequirementItem(
                      text: 'Documents must be valid and not expired',
                    ),
                    _RequirementItem(
                      text: 'Full document must be visible in the photo',
                    ),
                    _RequirementItem(
                      text: 'No edited or tampered documents',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentStatus {
  final String status;
  final String? imagePath;

  DocumentStatus({required this.status, this.imagePath});
}

class _DocumentCard extends StatelessWidget {
  final String documentName;
  final String status;
  final String? imagePath;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;
  final VoidCallback onUpload;

  const _DocumentCard({
    required this.documentName,
    required this.status,
    required this.imagePath,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Medium',
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              icon: Icon(
                imagePath != null ? Icons.refresh : Icons.upload_file,
                size: 18,
              ),
              label: Text(
                imagePath != null ? 'Re-upload' : 'Upload Document',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Bold',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: const BorderSide(color: AppColors.primaryRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String text;

  const _RequirementItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
