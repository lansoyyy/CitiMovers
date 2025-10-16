import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../models/driver_model.dart';

class DriverCredentialsScreen extends StatelessWidget {
  final DriverModel driver;

  const DriverCredentialsScreen({
    super.key,
    required this.driver,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Driver Credentials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Legal Protection'),
                  content: const Text(
                    'These credentials are watermarked and for verification purposes only.\n\n'
                    '• Unauthorized use is prohibited\n'
                    '• Screenshots are tracked\n'
                    '• Will auto-hide after delivery\n'
                    '• Legal action for misuse\n\n'
                    'By viewing, you agree to these terms.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('I Understand'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Warning Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade900,
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For verification only • Unauthorized use prohibited',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Driver License
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver\'s License',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WatermarkedImage(
                    imageUrl: driver.licensePhotoUrl ??
                        'https://via.placeholder.com/400x250',
                    watermarkText: 'FOR VERIFICATION ONLY\n${driver.name}',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge,
                          color: AppColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'License Number',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Regular',
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                driver.licenseNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Bold',
                                  color: AppColors.white,
                                ),
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

            const SizedBox(height: 32),

            // Vehicle Registration (if available)
            if (driver.vehiclePhotoUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Registration',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WatermarkedImage(
                      imageUrl: driver.vehiclePhotoUrl!,
                      watermarkText:
                          'FOR VERIFICATION ONLY\n${driver.vehiclePlateNumber}',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            color: AppColors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Plate Number',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Regular',
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  driver.vehiclePlateNumber,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Bold',
                                    color: AppColors.white,
                                  ),
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

            const SizedBox(height: 32),

            // Auto-Hide Notice
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade800,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Auto-Hide Protection',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These credentials will be automatically hidden after delivery completion for security purposes.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Legal Notice
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.shade900,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.gavel,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Legal Protection',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Bold',
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• All credentials are watermarked\n'
                      '• Unauthorized reproduction is illegal\n'
                      '• Screenshots are monitored\n'
                      '• Misuse will result in legal action\n'
                      '• Access is logged and tracked',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: Colors.grey.shade300,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Watermarked Image Widget
class _WatermarkedImage extends StatelessWidget {
  final String imageUrl;
  final String watermarkText;

  const _WatermarkedImage({
    required this.imageUrl,
    required this.watermarkText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Image
          Image.network(
            imageUrl,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 50,
                  ),
                ),
              );
            },
          ),

          // Watermark Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.3),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      watermarkText,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Bold',
                        color: AppColors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Corner Watermarks
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CONFIDENTIAL',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Bold',
                  color: AppColors.white,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateTime.now().toString().substring(0, 19),
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: 'Regular',
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
