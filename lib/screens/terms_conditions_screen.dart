import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  void _shareTermsAndConditions(BuildContext context) {
    final shareText = '''
CitiMovers Terms & Conditions

Welcome to CitiMovers. These Terms and Conditions govern your use of our delivery services and mobile application.

Key Points:
• Services: Professional delivery drivers with various vehicle types
• User Account: Must be 18+, provide accurate information
• Booking: Prices based on distance, vehicle type, and time
• Prohibited Items: Illegal substances, weapons, hazardous materials
• Insurance: Basic coverage up to ₱5,000 included
• Cancellation: Free within 5 minutes, charges apply after

For full details, download the CitiMovers app or visit our website.

Contact: legal@citimovers.com | Phone: 09090104355
© 2025 CitiMovers. All rights reserved.
    ''';

    Share.share(
      shareText.trim(),
      subject: 'CitiMovers Terms & Conditions',
    );
  }

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
          'Terms & Conditions',
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
            onPressed: () => _shareTermsAndConditions(context),
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
                color: AppColors.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryRed.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Last updated: October 28, 2025',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Medium',
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              '1. Introduction',
              'Welcome to CitiMovers. These Terms and Conditions govern your use of our delivery services and mobile application. By using CitiMovers, you agree to these terms.',
            ),

            _buildSection(
              '2. Services',
              'CitiMovers provides a platform connecting users with professional delivery drivers. We offer various vehicle types including motorcycles, 4-wheelers, 6-wheelers, and wingvans for different delivery needs within Metro Manila and surrounding areas.',
            ),

            _buildSection(
              '3. User Account',
              'To use our services, you must:\n'
                  '• Be at least 18 years old\n'
                  '• Provide accurate and complete information\n'
                  '• Maintain the security of your account\n'
                  '• Notify us immediately of unauthorized use\n'
                  '• Not share your account credentials with others',
            ),

            _buildSection(
              '4. Booking and Payment',
              '• All bookings are subject to availability\n'
                  '• Prices are calculated based on distance, vehicle type, and time\n'
                  '• Payment must be made using accepted payment methods\n'
                  '• Additional charges may apply for special requirements\n'
                  '• Cancellation fees may apply after 5 minutes of booking',
            ),

            _buildSection(
              '5. Delivery Guidelines',
              '• Items must be legally permissible for transport\n'
                  '• Hazardous materials are strictly prohibited\n'
                  '• Items must be properly packaged and secured\n'
                  '• Weight limits vary by vehicle type\n'
                  '• Users must provide accurate pickup and delivery locations',
            ),

            _buildSection(
              '6. Prohibited Items',
              'The following items are prohibited from delivery:\n'
                  '• Illegal substances and controlled drugs\n'
                  '• Weapons and ammunition\n'
                  '• Explosive and flammable materials\n'
                  '• Perishable goods requiring refrigeration\n'
                  '• Live animals and pets\n'
                  '• Human remains or body parts\n'
                  '• Stolen property',
            ),

            _buildSection(
              '7. Liability and Insurance',
              '• Basic insurance coverage up to ₱5,000 is included\n'
                  '• Additional insurance available for high-value items\n'
                  '• CitiMovers is not liable for undocumented damages\n'
                  '• Users must report damages within 24 hours\n'
                  '• We are not responsible for delays due to traffic or weather',
            ),

            _buildSection(
              '8. Driver Conduct',
              'All drivers must:\n'
                  '• Maintain professional conduct\n'
                  '• Follow traffic laws and regulations\n'
                  '• Handle items with reasonable care\n'
                  '• Maintain clean and roadworthy vehicles\n'
                  '• Respect user privacy and property',
            ),

            _buildSection(
              '9. Cancellation Policy',
              '• Free cancellation within 5 minutes of booking\n'
                  '• 50% charge for cancellation after 5 minutes but before pickup\n'
                  '• Full charge for cancellation after driver arrival\n'
                  '• No charge for cancellations due to driver issues\n'
                  '• Refunds processed within 5-7 business days',
            ),

            _buildSection(
              '10. Privacy and Data Protection',
              'We collect and use your information in accordance with our Privacy Policy. By using CitiMovers, you consent to:\n'
                  '• Collection of location data for service delivery\n'
                  '• Storage of transaction history\n'
                  '• Communication regarding your bookings\n'
                  '• Use of data for service improvement\n'
                  '• Sharing information with drivers for delivery purposes',
            ),

            _buildSection(
              '11. Dispute Resolution',
              '• Contact customer support within 24 hours of incident\n'
                  '• Provide evidence such as photos or videos\n'
                  '• Allow 48-72 hours for investigation\n'
                  '• Accept final resolution from CitiMovers\n'
                  '• Legal disputes shall be governed by Philippine laws',
            ),

            _buildSection(
              '12. Suspension and Termination',
              'We may suspend or terminate your account for:\n'
                  '• Violation of these terms and conditions\n'
                  '• Fraudulent activities or false reports\n'
                  '• Harassment of drivers or staff\n'
                  '• Multiple unjustified cancellations\n'
                  '• Security concerns or suspicious activities',
            ),

            _buildSection(
              '13. Changes to Terms',
              'We reserve the right to modify these terms at any time. Changes will be:\n'
                  '• Posted in the app with effective date\n'
                  '• Sent via email or notification\n'
                  '• Effective upon posting\n'
                  '• Your continued use constitutes acceptance',
            ),

            _buildSection(
              '14. Contact Information',
              'For questions about these Terms and Conditions, contact us:\n'
                  '• Email: legal@citimovers.com\n'
                  '• Phone: 09090104355\n'
                  '• Office: 123 Business Ave, Makati City\n'
                  '• Hours: Monday to Saturday, 8:00 AM to 6:00 PM',
            ),

            const SizedBox(height: 32),

            // Agreement Checkbox
            Container(
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
                    'Agreement to Terms',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'By continuing to use CitiMovers, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '© 2025 CitiMovers. All rights reserved.',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Regular',
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.lightGrey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
