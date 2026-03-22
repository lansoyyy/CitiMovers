import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const _googlePlayRidersUrl =
    'https://play.google.com/store/apps/details?id=com.algovision.citimovers_drivers&pli=1';

const _googlePlayCustomersUrl =
    'https://drive.google.com/file/d/17w4Q23UeoBgiz7wHJi31PAvSzdDZ5YC7/view?usp=sharing';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Shows a "Coming Soon" dialog for the App Store button.
void showAppStoreComingSoonDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.apple_rounded,
                size: 34,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Coming Soon',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The CitiMovers app on the iOS App Store is currently in development. Stay tuned!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Got it',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a dialog to pick between Customers and Riders app on Google Play.
void showGooglePlayChoiceDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.android_rounded,
                size: 34,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Your App',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the CitiMovers app you want to download.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _AppChoiceTile(
              icon: Icons.person_rounded,
              title: 'Customers App',
              subtitle: 'Book deliveries & track your cargo',
              onTap: () {
                Navigator.of(ctx).pop();
                _openUrl(_googlePlayCustomersUrl);
              },
            ),
            const SizedBox(height: 12),
            _AppChoiceTile(
              icon: Icons.local_shipping_rounded,
              title: 'Riders / Drivers App',
              subtitle: 'Accept jobs & manage your trips',
              onTap: () {
                Navigator.of(ctx).pop();
                _openUrl(_googlePlayRidersUrl);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a general download dialog that lets the user choose platform first,
/// then (for Google Play) the app type.
void showGeneralDownloadDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 34,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Download CitiMovers',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your platform to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _AppChoiceTile(
              icon: Icons.android_rounded,
              title: 'Google Play',
              subtitle: 'Android phones & tablets',
              onTap: () {
                Navigator.of(ctx).pop();
                showGooglePlayChoiceDialog(context);
              },
            ),
            const SizedBox(height: 12),
            _AppChoiceTile(
              icon: Icons.apple_rounded,
              title: 'App Store',
              subtitle: 'iPhone & iPad',
              onTap: () {
                Navigator.of(ctx).pop();
                showAppStoreComingSoonDialog(context);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AppChoiceTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AppChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_AppChoiceTile> createState() => _AppChoiceTileState();
}

class _AppChoiceTileState extends State<_AppChoiceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF1565C0).withOpacity(0.07)
                : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF1565C0).withOpacity(0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: const Color(0xFF1565C0),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _hovered ? const Color(0xFF1565C0) : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
