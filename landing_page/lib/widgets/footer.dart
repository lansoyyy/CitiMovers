import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060E1C), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: 60,
        horizontal: isMobile ? 24 : 60,
      ),
      child: Column(
        children: [
          isMobile ? _buildMobileFooter() : _buildDesktopFooter(),
          const SizedBox(height: 48),
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 24),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildDesktopFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand column
        Expanded(flex: 3, child: _buildBrandColumn()),
        const SizedBox(width: 60),

        // Quick links
        Expanded(
          flex: 2,
          child: _buildLinksColumn('Quick Links', [
            'Features',
            'Vehicle Fleet',
            'How It Works',
            'Download App',
          ]),
        ),

        // Services
        Expanded(
          flex: 2,
          child: _buildLinksColumn('Services', [
            'Same-Day Delivery',
            'Scheduled Booking',
            'Corporate Logistics',
            'Bulk Cargo',
          ]),
        ),

        // Contact
        Expanded(flex: 3, child: _buildContactColumn()),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandColumn(),
        const SizedBox(height: 40),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLinksColumn('Quick Links', [
                'Features',
                'Vehicle Fleet',
                'How It Works',
                'Download App',
              ]),
            ),
            Expanded(
              child: _buildLinksColumn('Services', [
                'Same-Day Delivery',
                'Scheduled Booking',
                'Corporate Logistics',
                'Bulk Cargo',
              ]),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _buildContactColumn(),
      ],
    );
  }

  Widget _buildBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/images/logo.png', height: 48),
        const SizedBox(height: 16),
        Text(
          'Your Reliable Delivery Partner',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white54,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Professional logistics and cargo delivery across Metro Manila. '
            'From small parcels to heavy industrial loads — we\'ve got you covered.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white38,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Social links
        Row(
          children: [
            _FooterSocialBtn(
              icon: Icons.facebook_rounded,
              url: 'https://www.facebook.com/Citimovers/',
            ),
            const SizedBox(width: 10),
            _FooterSocialBtn(
              icon: Icons.email_rounded,
              url: 'mailto:excel_gesite@yahoo.com',
            ),
            const SizedBox(width: 10),
            _FooterSocialBtn(
              icon: Icons.phone_rounded,
              url: 'tel:+639674893335',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinksColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FooterLink(label: link),
          ),
        ),
      ],
    );
  }

  Widget _buildContactColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Us',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        _FooterContactItem(
          icon: Icons.location_on_outlined,
          text:
              '24 JP Rizal St. Cor. Visayas St.\nBrgy. Sta. Lucia, Novaliches\nQuezon City 1117',
        ),
        const SizedBox(height: 12),
        _FooterContactItem(
          icon: Icons.phone_outlined,
          text: '0967 489 3335',
          url: 'tel:+639674893335',
        ),
        const SizedBox(height: 12),
        _FooterContactItem(
          icon: Icons.email_outlined,
          text: 'excel_gesite@yahoo.com',
          url: 'mailto:excel_gesite@yahoo.com',
        ),
        const SizedBox(height: 12),
        _FooterContactItem(
          icon: Icons.map_outlined,
          text: 'Metro Manila, Philippines',
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Builder(
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 768;
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          children: [
            Text(
              '© ${DateTime.now().year} CitiMovers. All rights reserved.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
            ),
            if (!isMobile) const SizedBox(width: 40),
            Text(
              'Metro Manila, Philippines',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
            ),
          ],
        );
      },
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  const _FooterLink({required this.label});

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: _hovered ? AppColors.primaryLight : Colors.white38,
        ),
        child: Text(widget.label),
      ),
    );
  }
}

class _FooterContactItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final String? url;
  const _FooterContactItem({required this.icon, required this.text, this.url});

  @override
  State<_FooterContactItem> createState() => _FooterContactItemState();
}

class _FooterContactItemState extends State<_FooterContactItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.url != null
            ? () => launchUrl(Uri.parse(widget.url!))
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              widget.icon,
              size: 16,
              color: _hovered && widget.url != null
                  ? AppColors.primaryLight
                  : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.text,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _hovered && widget.url != null
                      ? AppColors.primaryLight
                      : Colors.white38,
                  height: 1.6,
                  decoration: widget.url != null && _hovered
                      ? TextDecoration.underline
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterSocialBtn extends StatefulWidget {
  final IconData icon;
  final String url;
  const _FooterSocialBtn({required this.icon, required this.url});

  @override
  State<_FooterSocialBtn> createState() => _FooterSocialBtnState();
}

class _FooterSocialBtnState extends State<_FooterSocialBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withOpacity(0.6)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Icon(
            widget.icon,
            color: _hovered ? Colors.white : Colors.white38,
            size: 18,
          ),
        ),
      ),
    );
  }
}
