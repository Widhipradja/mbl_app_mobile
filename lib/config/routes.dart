import 'package:go_router/go_router.dart';
import '../screens/landing_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/info/info_screens.dart';
import '../screens/launcher/information_hub_screen.dart';
import '../screens/savings/amal_jariyah_screen.dart';
import '../screens/savings/kurban_screen.dart';
import '../screens/budget/budget_wallet_screen.dart';
import '../screens/events/events_list_screen.dart';
import '../screens/finance/finance_dashboard_screen.dart';
import '../screens/zakatfitrah/add_muzakki_screen.dart';
import '../screens/zakatfitrah/zakat_transaction_screen.dart';
import '../models/muzakki.dart';
import '../screens/zakatfitrah/zakat_shell_screen.dart';
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

      if (isGoingToSplash) return null;

      // Check token expiry if authenticated
      if (isAuthenticated) {
        final token = StorageService.getToken();
        if (token != null && JwtDecoder.isExpired(token)) {
          // Token expired, clear storage and redirect to landing
          await StorageService.clearAll();
          return isGoingToLanding ? null : '/landing';
        }
        // Already signed in: skip the landing page
        if (isGoingToLanding) return '/dashboard';
      }

      // Allow landing page to show without authentication
      if (isGoingToLanding) return null;

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

      // Read-only info screens behind the home summary cards
      GoRoute(
        path: '/info/hub',
        builder: (context, state) => const InformationHubScreen(),
      ),
      GoRoute(
        path: '/info/jimpitan',
        builder: (context, state) => const JimpitanScreen(),
      ),
      GoRoute(
        path: '/info/fundraising',
        builder: (context, state) => const FundraisingScreen(),
      ),

      // Tabungan Kurban and Buku Amal Jariyah
      GoRoute(
        path: '/kurban',
        builder: (context, state) => const KurbanScreen(),
      ),
      GoRoute(
        path: '/amal-jariyah',
        builder: (context, state) => const AmalJariyahScreen(),
      ),

      // Events: list, detail and (for writers) create/edit/delete.
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsListScreen(),
      ),

      // Finance layout preview (sample data until the API is ready)
      GoRoute(
        path: '/finance',
        builder: (context, state) => const FinanceDashboardScreen(),
      ),

      // Budget: the personal wallet; its other screens are pushed.
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetWalletScreen(),
      ),

      // Zakat Fitrah Module Routes
      GoRoute(
        path: '/zakat-fitrah',
        builder: (context, state) => const ZakatShellScreen(),
      ),
      GoRoute(
        path: '/zakat-fitrah/muzakki',
        builder: (context, state) => const ZakatShellScreen(initialTab: 1),
      ),
      GoRoute(
        path: '/zakat-fitrah/laporan',
        builder: (context, state) => const ZakatShellScreen(initialTab: 2),
      ),
      GoRoute(
        path: '/zakat-fitrah/configuration',
        builder: (context, state) => const ZakatShellScreen(initialTab: 4),
      ),
      GoRoute(
        path: '/zakat-fitrah/mustahiq',
        builder: (context, state) => const ZakatShellScreen(initialTab: 3),
      ),
      GoRoute(
        path: '/zakat-fitrah/add',
        builder: (context, state) => AddMuzakkiScreen(
          initialFamilyId: state.uri.queryParameters['family_id'] ?? '',
          initialMuzakki:
              state.extra is Muzakki ? state.extra as Muzakki : null,
        ),
      ),
      GoRoute(
        path: '/zakat-fitrah/transaction',
        builder: (context, state) {
          final muzakki = state.extra as Muzakki?;
          if (muzakki == null) return const ZakatShellScreen(initialTab: 0);
          return ZakatTransactionScreen(muzakki: muzakki);
        },
      ),

      // Old entry point (the splash screen once opened the budget home).
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/dashboard',
      ),
    ],
  );
}
