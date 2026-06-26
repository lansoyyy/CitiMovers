import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/rider_document_requirements.dart';
import '../../../utils/ui_helpers.dart';
import '../../services/rider_auth_service.dart';

class RiderDocumentsScreen extends StatefulWidget {
  const RiderDocumentsScreen({super.key});

  @override
  State<RiderDocumentsScreen> createState() => _RiderDocumentsScreenState();
}

class _RiderDocumentsScreenState extends State<RiderDocumentsScreen> {
  final _authService = RiderAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUploading = false;
  String? _uploadingKey;
  final Map<String, _DocumentEntry> _documents = {};

  @override
  void initState() {
    super.initState();
    _seedRequiredDocuments();
    _loadDocuments();
  }

  void _seedRequiredDocuments() {
    for (final entry in RiderDocumentRequirements.allDocuments) {
      final (label, key) = entry;
      _documents.putIfAbsent(
        key,
        () => _DocumentEntry(label: label, status: 'not_uploaded'),
      );
    }
  }

  Future<void> _loadDocuments() async {
    final rider = _authService.currentRider;
    if (rider == null) return;

    try {
      final docSnapshot =
          await _firestore.collection('riders').doc(rider.riderId).get();

      if (!docSnapshot.exists) return;

      final rawDocuments = docSnapshot.data()?['documents'];
      if (rawDocuments is! Map) return;

      final documents = rawDocuments.map(
        (k, v) => MapEntry(k.toString(), v),
      );

      if (!mounted) return;

      setState(() {
        for (final entry in RiderDocumentRequirements.allDocuments) {
          final (label, key) = entry;
          final docData = RiderDocumentRequirements.findDocumentData(
            Map<String, dynamic>.from(documents),
            key,
          );
          final url = RiderDocumentRequirements.resolveUrl(docData);
          final status = RiderDocumentRequirements.resolveStatus(
            docData,
            url: url,
          );
          _documents[key] = _DocumentEntry(
            label: label,
            status: status,
            url: url.isNotEmpty ? url : null,
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
    }
  }

  Future<void> _pickDocument(String documentKey, String documentLabel) async {
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

    if (image == null) return;

    setState(() {
      _isUploading = true;
      _uploadingKey = documentKey;
      _documents[documentKey] = _DocumentEntry(
        label: documentLabel,
        status: 'pending',
        localPath: image.path,
      );
    });

    final success = await _authService.uploadRiderDocuments({
      documentLabel: image.path,
    });

    if (!mounted) return;

    setState(() {
      _isUploading = false;
      _uploadingKey = null;
      if (!success) {
        _documents[documentKey] = _DocumentEntry(
          label: documentLabel,
          status: 'not_uploaded',
        );
      }
    });

    if (success) {
      UIHelpers.showSuccessToast('$documentLabel uploaded');
      await _loadDocuments();
    } else {
      UIHelpers.showErrorToast('Failed to upload $documentLabel');
    }
  }

  Future<void> _openDocumentExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      UIHelpers.showErrorToast('Invalid document link');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      UIHelpers.showErrorToast('Could not open document');
    }
  }

  void _showDocumentViewer({
    required String title,
    required String url,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: AppColors.white,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.lightGrey.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openDocumentExternally(url),
                        icon: const Icon(Icons.open_in_new),
                        tooltip: 'Open in browser',
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: AppColors.scaffoldBackground,
                    child: InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return UIHelpers.loadingThreeBounce(
                              color: AppColors.primaryRed,
                              size: 20,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    size: 42,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Unable to preview this file in-app.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Medium',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: () => _openDocumentExternally(url),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open in Browser'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'pending':
      case 'uploaded':
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
      case 'uploaded':
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
      case 'uploaded':
        return Icons.access_time;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.upload_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = RiderDocumentRequirements.allDocuments
        .map((entry) {
          final (label, key) = entry;
          final doc = _documents[key] ??
              _DocumentEntry(label: label, status: 'not_uploaded');
          return MapEntry(key, doc);
        })
        .toList();

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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primaryBlue),
                    SizedBox(width: 12),
                    Expanded(
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
              ...entries.map((entry) {
                final key = entry.key;
                final doc = entry.value;
                final isUploadingThis = _isUploading && _uploadingKey == key;
                return _DocumentCard(
                  documentName: doc.label,
                  status: doc.status,
                  statusColor: _getStatusColor(doc.status),
                  statusText: _getStatusText(doc.status),
                  statusIcon: _getStatusIcon(doc.status),
                  isUploading: isUploadingThis,
                  canView: (doc.url ?? '').isNotEmpty,
                  onUpload: () => _pickDocument(key, doc.label),
                  onView: (doc.url ?? '').isNotEmpty
                      ? () => _showDocumentViewer(title: doc.label, url: doc.url!)
                      : null,
                );
              }),
              const SizedBox(height: 24),
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, color: AppColors.primaryRed),
                        SizedBox(width: 12),
                        Text(
                          'Document Requirements',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
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

class _DocumentEntry {
  final String label;
  final String status;
  final String? url;
  final String? localPath;

  _DocumentEntry({
    required this.label,
    required this.status,
    this.url,
    this.localPath,
  });
}

class _DocumentCard extends StatelessWidget {
  final String documentName;
  final String status;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;
  final bool isUploading;
  final bool canView;
  final VoidCallback onUpload;
  final VoidCallback? onView;

  const _DocumentCard({
    required this.documentName,
    required this.status,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
    required this.isUploading,
    required this.canView,
    required this.onUpload,
    this.onView,
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
                child: Icon(Icons.description, color: statusColor, size: 24),
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
                        Icon(statusIcon, size: 14, color: statusColor),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(canView ? Icons.refresh : Icons.upload_file,
                          size: 18),
                  label: Text(canView ? 'Re-upload' : 'Upload Document'),
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
              if (canView) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onView,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(fontSize: 14, fontFamily: 'Bold'),
                  ),
                ),
              ],
            ],
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
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
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
