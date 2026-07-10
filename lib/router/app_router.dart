import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/terms_screen.dart';
import '../screens/user/user_shell.dart';
import '../screens/user/home_screen.dart';
import '../screens/user/report_form_screen.dart';
import '../screens/user/report_tracking_screen.dart';
import '../screens/user/my_reports_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_report_detail_screen.dart';
import '../screens/admin/admin_analytics_screen.dart';
import '../screens/admin/admin_manage_authorities_screen.dart';
import '../screens/authority/authority_shell.dart';
import '../screens/authority/authority_dashboard_screen.dart';
import '../screens/authority/authority_case_detail_screen.dart';

import '../screens/shared/kerala_map_screen.dart';
import '../screens/user/rehab_chat_screen.dart';
import '../screens/user/rehab_centres_screen.dart';

/// App router configuration using go_router
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthService authService) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      redirect: (context, state) async {
        final user = FirebaseAuth.instance.currentUser;
        final isOnAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/terms' ||
            state.matchedLocation == '/splash';

        // Not logged in → redirect to login (unless already on auth routes)
        if (user == null && !isOnAuthRoute) {
          return '/login';
        }

        return null;
      },
      routes: [
        // ─── Splash ───
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // ─── Auth Routes ───
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => const TermsScreen(),
        ),
        
        // ─── Shared Routes ───
        GoRoute(
          path: '/map',
          builder: (context, state) => const KeralaMapScreen(),
        ),

        // ─── End User Shell ───
        ShellRoute(
          builder: (context, state, child) => UserShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/track',
              builder: (context, state) => const MyReportsScreen(),
            ),
            GoRoute(
              path: '/track/:reportId',
              builder: (context, state) => ReportTrackingScreen(
                reportId: state.pathParameters['reportId']!,
              ),
            ),
            GoRoute(
              path: '/report',
              builder: (context, state) => const ReportFormScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/rehab/chat',
              builder: (context, state) => const RehabChatScreen(),
            ),
            GoRoute(
              path: '/rehab/centres',
              builder: (context, state) => const RehabCentresScreen(),
            ),
          ],
        ),

        // ─── Admin Shell ───
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminDashboardScreen(),
            ),
            GoRoute(
              path: '/admin/report/:reportId',
              builder: (context, state) => AdminReportDetailScreen(
                reportId: state.pathParameters['reportId']!,
              ),
            ),
            GoRoute(
              path: '/admin/analytics',
              builder: (context, state) => const AdminAnalyticsScreen(),
            ),
            GoRoute(
              path: '/admin/authorities',
              builder: (context, state) =>
                  const AdminManageAuthoritiesScreen(),
            ),
            GoRoute(
              path: '/admin/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // ─── Authority Shell ───
        ShellRoute(
          builder: (context, state, child) => AuthorityShell(child: child),
          routes: [
            GoRoute(
              path: '/authority',
              builder: (context, state) => const AuthorityDashboardScreen(),
            ),
            GoRoute(
              path: '/authority/case/:reportId',
              builder: (context, state) => AuthorityCaseDetailScreen(
                reportId: state.pathParameters['reportId']!,
              ),
            ),
            GoRoute(
              path: '/authority/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
