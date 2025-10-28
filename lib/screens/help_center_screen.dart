import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/ui_helpers.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

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
          'Help Center',
          style: TextStyle(
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
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Search for help...',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: AppColors.primaryRed,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Help Categories
            const Text(
              'Quick Help',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: _helpCategories.length,
              itemBuilder: (context, index) {
                final category = _helpCategories[index];
                return _buildHelpCategory(context, category);
              },
            ),

            const SizedBox(height: 32),

            // Popular FAQs
            const Text(
              'Popular FAQs',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._faqs.asMap().entries.map((entry) {
              final index = entry.key;
              final faq = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFAQItem(context, faq, index),
              );
            }).toList(),

            const SizedBox(height: 32),

            // Contact Support
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryRed.withOpacity(0.1),
                    AppColors.primaryRed.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryRed.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryRed,
                          AppColors.primaryRed.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Still need help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is available 24/7',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactButton(
                          context,
                          'Call Us',
                          Icons.phone,
                          () => _launchPhone(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildContactButton(
                          context,
                          'Email Us',
                          Icons.email,
                          () => _launchEmail(),
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

  Widget _buildHelpCategory(BuildContext context, HelpCategory category) {
    return GestureDetector(
      onTap: () {
        _showCategoryDetails(context, category);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              category.title,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Bold',
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${category.articles} articles',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, FAQ faq, int index) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.question_answer,
            color: AppColors.primaryRed,
            size: 20,
          ),
        ),
        title: Text(
          faq.question,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Medium',
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              faq.answer,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Regular',
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: AppColors.primaryRed,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Medium',
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryDetails(BuildContext context, HelpCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category.icon,
                      color: category.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Bold',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${category.articles} articles',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Regular',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: category.articles,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.lightGrey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.article_outlined,
                            color: AppColors.textHint,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${category.title} Article ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Medium',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Learn more about ${category.title.toLowerCase()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Regular',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textHint,
                          size: 16,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchPhone() async {
    const phoneNumber = '09090104355';
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      UIHelpers.showErrorToast('Could not launch phone dialer');
    }
  }

  void _launchEmail() async {
    final uri = Uri.parse('mailto:support@citimovers.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      UIHelpers.showErrorToast('Could not launch email client');
    }
  }
}

class HelpCategory {
  final String title;
  final IconData icon;
  final Color color;
  final int articles;

  HelpCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.articles,
  });
}

class FAQ {
  final String question;
  final String answer;

  FAQ({
    required this.question,
    required this.answer,
  });
}

final List<HelpCategory> _helpCategories = [
  HelpCategory(
    title: 'Booking',
    icon: Icons.calendar_today,
    color: AppColors.primaryRed,
    articles: 12,
  ),
  HelpCategory(
    title: 'Payment',
    icon: Icons.payment,
    color: Colors.green,
    articles: 8,
  ),
  HelpCategory(
    title: 'Delivery',
    icon: Icons.local_shipping,
    color: AppColors.primaryBlue,
    articles: 15,
  ),
  HelpCategory(
    title: 'Account',
    icon: Icons.person,
    color: Colors.purple,
    articles: 6,
  ),
];

final List<FAQ> _faqs = [
  FAQ(
    question: 'How do I book a delivery?',
    answer: 'To book a delivery, simply open the app, select "Book Delivery", enter your pickup and drop-off locations, choose your vehicle type, and confirm your booking. You can track your delivery in real-time once it\'s assigned to a driver.',
  ),
  FAQ(
    question: 'What payment methods are accepted?',
    answer: 'CitiMovers accepts cash on delivery, credit/debit cards, and digital wallets like GCash and PayMaya. You can select your preferred payment method during the booking process.',
  ),
  FAQ(
    question: 'How can I track my delivery?',
    answer: 'Once your booking is confirmed and a driver is assigned, you can track your delivery in real-time through the app. Go to "My Bookings" and tap on your active booking to see the live tracking map.',
  ),
  FAQ(
    question: 'What if I need to cancel my booking?',
    answer: 'You can cancel your booking free of charge up to 5 minutes after confirmation. After that, a cancellation fee may apply. Go to "My Bookings", select the booking you want to cancel, and tap "Cancel Booking".',
  ),
  FAQ(
    question: 'Are my items insured during delivery?',
    answer: 'Yes, all deliveries through CitiMovers include basic insurance coverage up to ₱5,000. You can purchase additional insurance for high-value items during the booking process.',
  ),
];
