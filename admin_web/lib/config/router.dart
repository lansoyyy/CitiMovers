import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/login/login_screen.dart';
import '../screens/shell/admin_shell.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/riders/riders_screen.dart';
import '../screens/riders/rider_detail_screen.dart';
import '../screens/bookings/bookings_screen.dart';
import '../screens/bookings/booking_detail_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/promos/promos_screen.dart';
import '../screens/audit_logs/audit_logs_screen.dart';
import '../screens/maintenance/maintenance_screen.dart';
import '../services/auth_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AdminAuthService auth) => GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final isLoggedIn = auth.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';
        if (!isLoggedIn && !isLoginRoute) return '/login';
        if (isLoggedIn && isLoginRoute) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) =>
              AdminShell(child: child, currentPath: state.matchedLocation),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/customers',
              builder: (context, state) => const CustomersScreen(),
            ),
            GoRoute(
              path: '/customers/:id',
              builder: (context, state) =>
                  CustomerDetailScreen(customerId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/riders',
              builder: (context, state) => const RidersScreen(),
            ),
            GoRoute(
              path: '/riders/:id',
              builder: (context, state) =>
                  RiderDetailScreen(riderId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const BookingsScreen(),
            ),
            GoRoute(
              path: '/bookings/:id',
              builder: (context, state) =>
                  BookingDetailScreen(bookingId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/finance',
              builder: (context, state) => const FinanceScreen(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/promos',
              builder: (context, state) => const PromosScreen(),
            ),
            GoRoute(
              path: '/audit-logs',
              builder: (context, state) => const AuditLogsScreen(),
            ),
            GoRoute(
              path: '/maintenance',
              builder: (context, state) => const MaintenanceScreen(),
            ),
          ],
        ),
      ],
    );
