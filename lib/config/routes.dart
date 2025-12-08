import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/budget/budget_home_screen.dart';
import '../screens/budget/add_transaction_screen.dart';
import '../screens/budget/transaction_list_screen.dart';
import '../screens/contacts/contacts_home_screen.dart';
import '../services/storage_service.dart';
import '../utils/jwt_decoder.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final isAuthenticated = await StorageService.isAuthenticated();
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSplash = state.matchedLocation == '/splash';

      if (isGoingToSplash) return null;

      // Check token expiry if authenticated
      if (isAuthenticated) {
        final token = StorageService.getToken();
        if (token != null && JwtDecoder.isExpired(token)) {
          // Token expired, clear storage and redirect to login
          await StorageService.clearAll();
          return '/login';
        }
      }

      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }

      if (isAuthenticated && isGoingToLogin) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
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
        path: '/budget/transactions',
        builder: (context, state) => const TransactionListScreen(),
      ),

      // Contacts Module Routes
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsHomeScreen(),
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
