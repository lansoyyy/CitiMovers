import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/ui_helpers.dart';

class WhyChooseUsScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const WhyChooseUsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

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
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.white,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'Bold',
                      color: AppColors.white,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Medium',
                      color: AppColors.white,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Detailed Information
            _buildDetailSection(
              context,
              'What This Means for You',
              _getDetailDescription(title),
            ),

            const SizedBox(height: 24),

            // Benefits Section
            _buildDetailSection(
              context,
              'Key Benefits',
              _getBenefitsList(title),
            ),

            const SizedBox(height: 24),

            // How We Ensure This
            _buildDetailSection(
              context,
              'How We Ensure This',
              _getHowWeEnsureList(title),
            ),

            const SizedBox(height: 32),

            // Testimonial
            _buildTestimonialCard(title),

            const SizedBox(height: 32),

            // Contact Support Button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  UIHelpers.showInfoToast('Support feature coming soon');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.support_agent,
                      size: 20,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Bold',
                        color: AppColors.white,
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

  Widget _buildDetailSection(
      BuildContext context, String title, dynamic content) {
    return Container(
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
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          if (content is String)
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            )
          else if (content is List)
            ...content
                .map<Widget>((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Regular',
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(String featureType) {
    final testimonial = _getTestimonial(featureType);

    return Container(
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
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.format_quote,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Customer Testimonial',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            testimonial['quote'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Regular',
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    testimonial['initial'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testimonial['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      testimonial['role'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDetailDescription(String title) {
    switch (title) {
      case 'Verified Drivers':
        return 'All our drivers undergo a comprehensive background check and verification process before joining our platform. This includes identity verification, criminal background checks, driving record verification, and vehicle inspection. We ensure that only qualified, trustworthy individuals are approved to handle your deliveries.';
      case 'Real-time Tracking':
        return 'Our advanced GPS tracking system allows you to monitor your delivery in real-time from pickup to drop-off. You can see exactly where your package is, estimated arrival time, and receive notifications at key points during the delivery process. This transparency gives you peace of mind and helps you plan your day better.';
      case 'Secure Payment':
        return 'We prioritize the security of your financial information with industry-standard encryption and secure payment gateways. Multiple payment options are available, all processed through secure channels. Your payment details are never stored on our servers, and we comply with PCI DSS standards for payment security.';
      default:
        return 'Learn more about this feature and how it benefits your delivery experience.';
    }
  }

  List<String> _getBenefitsList(String title) {
    switch (title) {
      case 'Verified Drivers':
        return [
          'Peace of mind knowing your items are handled by trustworthy professionals',
          'Reduced risk of theft, damage, or mishandling of packages',
          'Professional service with proper training and etiquette',
          'Accountability with driver ratings and feedback system',
        ];
      case 'Real-time Tracking':
        return [
          'Complete visibility of your delivery journey',
          'Accurate ETAs to help you plan your schedule',
          'Proof of delivery with timestamp and location data',
          'Reduced anxiety about package whereabouts',
        ];
      case 'Secure Payment':
        return [
          'Protection of your financial information and personal data',
          'Multiple payment options for convenience',
          'Transparent pricing with no hidden fees',
          'Easy refunds and dispute resolution process',
        ];
      default:
        return ['Benefit 1', 'Benefit 2', 'Benefit 3'];
    }
  }

  List<String> _getHowWeEnsureList(String title) {
    switch (title) {
      case 'Verified Drivers':
        return [
          'Multi-step verification process including government ID checks',
          'Regular re-verification and background check updates',
          'In-person training sessions on proper handling procedures',
          'Continuous monitoring of driver performance and customer feedback',
        ];
      case 'Real-time Tracking':
        return [
          'Advanced GPS technology with location accuracy within 10 meters',
          'Regular system maintenance and updates to ensure reliability',
          'Backup tracking systems to prevent service interruptions',
          '24/7 technical support for tracking issues',
        ];
      case 'Secure Payment':
        return [
          'PCI DSS compliant payment processing systems',
          'End-to-end encryption for all financial transactions',
          'Regular security audits and vulnerability assessments',
          'Partnership with reputable payment gateway providers',
        ];
      default:
        return ['Method 1', 'Method 2', 'Method 3'];
    }
  }

  Map<String, String> _getTestimonial(String featureType) {
    switch (featureType) {
      case 'Verified Drivers':
        return {
          'quote':
              'I\'ve been using CitiMovers for my business deliveries for over a year now, and the professionalism of their drivers is unmatched. I never worry about my packages when they\'re in transit.',
          'name': 'Maria Santos',
          'role': 'Small Business Owner',
          'initial': 'MS',
        };
      case 'Real-time Tracking':
        return {
          'quote':
              'The real-time tracking feature is a game-changer for my busy schedule. I can see exactly when my delivery will arrive and plan my day accordingly. No more waiting around for hours!',
          'name': 'Juan Reyes',
          'role': 'Freelance Designer',
          'initial': 'JR',
        };
      case 'Secure Payment':
        return {
          'quote':
              'I was initially hesitant about online payments, but CitiMovers\' secure system gave me confidence. The multiple payment options and transparent pricing make it so convenient.',
          'name': 'Ana Lopez',
          'role': 'Online Shopper',
          'initial': 'AL',
        };
      default:
        return {
          'quote': 'Great service that exceeded my expectations!',
          'name': 'Happy Customer',
          'role': 'Regular User',
          'initial': 'HC',
        };
    }
  }
}
