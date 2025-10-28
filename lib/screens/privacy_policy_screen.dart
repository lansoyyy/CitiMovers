import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share,
              color: AppColors.primaryRed,
              size: 20,
            ),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Updated
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Last updated: October 28, 2025',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Medium',
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Privacy Commitment
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.1),
                    AppColors.primaryBlue.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: AppColors.primaryBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Privacy Matters',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We are committed to protecting your personal information and ensuring your privacy while using CitiMovers services.',
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

            const SizedBox(height: 24),

            // Privacy Sections
            _buildPrivacySection(
              '1. Information We Collect',
              [
                '• Personal Information: Name, phone number, email address',
                '• Location Data: GPS coordinates for pickup and delivery',
                '• Transaction Data: Booking history, payment information',
                '• Device Information: App usage, device type, operating system',
                '• Communication Data: Messages, call recordings with drivers',
                '• Feedback Data: Ratings, reviews, and customer support interactions',
              ],
            ),

            _buildPrivacySection(
              '2. How We Use Your Information',
              [
                '• To provide and maintain our delivery services',
                '• To process bookings and payments',
                '• To match you with suitable delivery drivers',
                '• To communicate about your bookings',
                '• To improve our services and user experience',
                '• For fraud prevention and security purposes',
                '• To comply with legal obligations',
              ],
            ),

            _buildPrivacySection(
              '3. Information Sharing',
              [
                '• With assigned drivers for delivery purposes',
                '• With payment processors for transactions',
                '• With service providers for operational support',
                '• With authorities when required by law',
                '• With business partners for service enhancement',
                '• Never sell your personal information to third parties',
              ],
            ),

            _buildPrivacySection(
              '4. Data Security',
              [
                '• 256-bit SSL encryption for all data transmission',
                '• Secure servers with firewalls and intrusion detection',
                '• Regular security audits and vulnerability assessments',
                '• Employee training on data protection',
                '• Limited access to personal information on need-to-know basis',
                '• Secure backup and disaster recovery systems',
              ],
            ),

            _buildPrivacySection(
              '5. Your Rights',
              [
                '• Right to access your personal information',
                '• Right to correct inaccurate information',
                '• Right to delete your account and data',
                '• Right to opt-out of marketing communications',
                '• Right to data portability',
                '• Right to know what data is collected and how it\'s used',
              ],
            ),

            _buildPrivacySection(
              '6. Cookies and Tracking',
              [
                '• Essential cookies for app functionality',
                '• Performance cookies to improve service quality',
                '• Analytics cookies to understand user behavior',
                '• Marketing cookies for personalized content',
                '• You can control cookie preferences in app settings',
              ],
            ),

            _buildPrivacySection(
              '7. Data Retention',
              [
                '• Transaction history retained for 7 years (tax compliance)',
                '• Account information retained until account deletion',
                '• Support tickets retained for 3 years',
                '• Marketing data retained for 2 years of inactivity',
                '• Deleted data securely erased within 30 days',
              ],
            ),

            _buildPrivacySection(
              '8. Children\'s Privacy',
              [
                '• Services not intended for users under 18',
                '• We do not knowingly collect information from children',
                '• Parents can request removal of their child\'s information',
                '• Immediate action taken upon age verification concerns',
              ],
            ),

            _buildPrivacySection(
              '9. International Data Transfers',
              [
                '• Data primarily stored within the Philippines',
                '• Some processing may occur in secure international servers',
                '• All transfers comply with Data Privacy Act of 2012',
                '• Adequate security measures for international transfers',
              ],
            ),

            _buildPrivacySection(
              '10. Changes to Privacy Policy',
              [
                '• Changes posted in app with effective date',
                '• Notifications sent for significant changes',
                '• 30-day notice for material changes',
                '• Continued use constitutes acceptance',
              ],
            ),

            const SizedBox(height: 32),

            // Contact Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Privacy Questions?',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If you have questions about this Privacy Policy or how we handle your data, please contact our Data Protection Officer.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildContactItem('Email', 'privacy@citimovers.com', Icons.email),
                        const SizedBox(height: 12),
                        _buildContactItem('Phone', '09090104355', Icons.phone),
                        const SizedBox(height: 12),
                        _buildContactItem('Office', '123 Business Ave, Makati City', Icons.location_on),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '© 2025 CitiMovers. Privacy is our priority.',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.lightGrey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: points.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  point,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Regular',
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildContactItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryBlue,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Medium',
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Medium',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
