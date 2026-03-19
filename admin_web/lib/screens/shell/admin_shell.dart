import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const AdminShell(
      {super.key, required this.child, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentPath: currentPath),
          Expanded(
            child: Column(
              children: [
                _TopBar(currentPath: currentPath),
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

final _navItems = [
  _NavItem('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  _NavItem('Customers', Icons.people_outlined, '/customers'),
  _NavItem('Riders', Icons.local_shipping_outlined, '/riders'),
  _NavItem('Bookings', Icons.receipt_long_outlined, '/bookings'),
  _NavItem('Finance', Icons.account_balance_wallet_outlined, '/finance'),
  _NavItem('Notifications', Icons.notifications_outlined, '/notifications'),
  _NavItem('Promo Banners', Icons.campaign_outlined, '/promos'),
  _NavItem('Audit Logs', Icons.history_outlined, '/audit-logs'),
  _NavItem('Maintenance', Icons.build_circle_outlined, '/maintenance'),
];

class _Sidebar extends StatelessWidget {
  final String currentPath;
  const _Sidebar({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AdminTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CitiMovers',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text('Admin Panel',
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.white12, height: 1),
          ),
          const SizedBox(height: 12),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isActive = currentPath.startsWith(item.route);
                return _NavTile(
                    item: item, isActive: isActive);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.white12, height: 1),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.all(12),
            child: _NavTile(
              item: _NavItem('Logout', Icons.logout_outlined, '/login'),
              isActive: false,
              onTap: () async {
                await AdminAuthService().logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavTile({required this.item, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AdminTheme.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 20,
        ),
        title: Text(
          item.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? Colors.white : Colors.white70,
          ),
        ),
        onTap: onTap ?? () => context.go(item.route),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String currentPath;
  const _TopBar({required this.currentPath});

  String get _title {
    if (currentPath.startsWith('/customers/')) return 'Customer Detail';
    if (currentPath.startsWith('/riders/')) return 'Rider Detail';
    if (currentPath.startsWith('/bookings/')) return 'Booking Detail';
    switch (currentPath) {
      case '/dashboard': return 'Dashboard';
      case '/customers': return 'Customers';
      case '/riders': return 'Riders';
      case '/bookings': return 'Bookings';
      case '/finance': return 'Finance & Reconciliation';
      case '/notifications': return 'Notifications';
      case '/promos': return 'Promo Banners';
      case '/audit-logs': return 'Audit Logs';
      case '/maintenance': return 'Maintenance';
      default: return 'Admin Panel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminTheme.divider)),
      ),
      child: Row(
        children: [
          Text(_title,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 16, color: AdminTheme.primary),
                const SizedBox(width: 6),
                Text('Administrator',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
