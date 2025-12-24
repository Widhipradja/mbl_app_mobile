import 'package:go_router/go_router.dart';
import '../screens/landing_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/budget/budget_home_screen.dart';
import '../screens/budget/add_transaction_screen.dart';
import '../screens/budget/transaction_list_screen.dart';
import '../screens/budget/search_transaction_screen.dart';
import '../screens/attendance/attendance_home_screen.dart';
import '../screens/attendance/event_detail_screen.dart';
import '../screens/attendance/event_inquiry_screen.dart';
import '../screens/kbm/kbm_setup_screen.dart';
import '../screens/kbm/kbm_list_screen.dart';
import '../screens/kbm/kbm_home_screen.dart';
import '../screens/member/member_list_screen.dart';
import '../models/event.dart';
import '../services/storage_service.dart';
import '../utils/jwt_decoder.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/landing',
    redirect: (context, state) async {
      final isAuthenticated = await StorageService.isAuthenticated();
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isGoingToLanding = state.matchedLocation == '/landing';

      // Allow landing page to show without authentication
      if (isGoingToLanding) return null;

      if (isGoingToSplash) return null;

      // Check token expiry if authenticated
      if (isAuthenticated) {
        final token = StorageService.getToken();
        if (token != null && JwtDecoder.isExpired(token)) {
          // Token expired, clear storage and redirect to landing
          await StorageService.clearAll();
          return '/landing';
        }
      }

      if (!isAuthenticated && !isGoingToLogin) {
        return '/landing';
      }

      if (isAuthenticated && isGoingToLogin) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // Budget Module Routes
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetHomeScreen(),
      ),
      GoRoute(
        path: '/budget/add-transaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/budget/edit-transaction',
        builder: (context, state) {
          final transaction = state.extra as dynamic;
          return AddTransactionScreen(transaction: transaction);
        },
      ),
      GoRoute(
        path: '/budget/transactions',
        builder: (context, state) => const TransactionListScreen(),
      ),
      GoRoute(
        path: '/budget/search',
        builder: (context, state) => const SearchTransactionScreen(),
      ),

      // Attendance Module Routes
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceHomeScreen(),
      ),
      GoRoute(
        path: '/attendance/inquiry',
        builder: (context, state) => const EventInquiryScreen(),
      ),
      GoRoute(
        path: '/attendance/event-detail',
        builder: (context, state) {
          final event = state.extra as Event;
          return EventDetailScreen(event: event);
        },
      ),

      // Member Module Routes
      GoRoute(
        path: '/members',
        builder: (context, state) => const MemberListScreen(),
      ),

      // KBM Module Routes
      GoRoute(path: '/kbm', builder: (context, state) => const KbmHomeScreen()),
      GoRoute(
        path: '/kbm/setup',
        builder: (context, state) => const KbmSetupScreen(),
      ),

      // Contacts - redirect to attendance
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const AttendanceHomeScreen(),
      ),

      // Keep legacy routes for backward compatibility
      GoRoute(
        path: '/home',
        builder: (context, state) => const BudgetHomeScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionListScreen(),
      ),
    ],
  );
}
