import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../features/cubits.dart';
import '../features/screens.dart';
import 'splash_screen.dart';

/// Keeps one [GoRouter] instance; re-runs [GoRouter.redirect] when auth changes.
class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

GoRouter createAppRouter(AuthCubit auth, AuthRouterRefresh refresh) => GoRouter(
      initialLocation: '/splash',
      refreshListenable: refresh,
      redirect: (context, state) {
        final a = auth.state;
        final p = state.uri.path;
        final authRoute = p == '/login' || p == '/register' || p == '/forgot';
        final bootstrapRoute = p == '/splash' || p == '/onboarding';
        // Only show splash during initial bootstrap — not while login/register is in progress.
        if (a.loading && !authRoute && p != '/onboarding') return p == '/splash' ? null : '/splash';
        if (a.authed) {
          if (authRoute) return a.isDriver ? '/driver' : '/home';
          if (p == '/splash') return a.isDriver ? '/driver' : '/home';
          if (a.isDriver && p.startsWith('/home')) return '/driver';
          return null;
        }
        // Unauthenticated: splash resolves onboarding vs login; allow those routes through.
        if (authRoute || bootstrapRoute) return null;
        return '/splash';
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/forgot', builder: (_, __) => const ForgotScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        // Outside the shells: shared by passenger and driver, and full-screen
        // so the bottom nav never covers the save button.
        GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
        GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordScreen()),
        // Standalone page for both roles: pushed on top of the shell so it has no
        // bottom nav and the back arrow returns to whatever opened it.
        GoRoute(
          path: '/notifications',
          pageBuilder: (_, __) => _slidePage(const NotificationsScreen()),
        ),
        ShellRoute(
          builder: (_, __, child) => PassengerScope(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, __) => _fadePage(const HomeScreen()),
            ),
            GoRoute(path: '/upcoming', builder: (_, __) => const UpcomingTripsScreen()),
            GoRoute(
              path: '/results',
              pageBuilder: (_, __) => _slidePage(const ResultsScreen()),
            ),
            GoRoute(
              path: '/trip',
              pageBuilder: (_, s) => _slidePage(TripDetailsScreen(trip: s.extra as Trip)),
            ),
            GoRoute(
              path: '/seats',
              pageBuilder: (_, s) => _slidePage(SeatsScreen(args: s.extra as SeatsArgs)),
            ),
            GoRoute(
              path: '/passengers',
              pageBuilder: (_, s) => _slidePage(PassengersScreen(args: s.extra as PassArgs)),
            ),
            GoRoute(
              path: '/payment',
              pageBuilder: (_, s) => _slidePage(PaymentScreen(draft: s.extra as BookingDraft)),
            ),
            GoRoute(
              path: '/ticket/:id',
              pageBuilder: (_, s) => _slidePage(TicketScreen(bookingId: s.pathParameters['id']!)),
            ),
            GoRoute(path: '/bookings', builder: (_, __) => const MyBookingsScreen()),
            GoRoute(path: '/bookings/:id', builder: (_, s) => BookingDetailsScreen(bookingId: s.pathParameters['id']!)),
            GoRoute(
              path: '/bookings/:id/modify',
              builder: (_, s) => ModifyBookingScreen(booking: s.extra as BookingDetails),
            ),
            GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ],
        ),
        ShellRoute(
          builder: (_, __, child) => DriverShell(child: child),
          routes: [
            GoRoute(path: '/driver', builder: (_, __) => const DriverScreen()),
            GoRoute(path: '/driver/trip', builder: (_, s) => DriverTripDetailsScreen(trip: s.extra as Trip)),
            GoRoute(
              path: '/driver/scan',
              builder: (_, s) => ScanScreen(trip: s.extra is Trip ? s.extra as Trip : null),
            ),
            GoRoute(path: '/driver/profile', builder: (_, __) => const ProfileScreen(isDriver: true)),
          ],
        ),
      ],
    );

CustomTransitionPage<void> _fadePage(Widget child) => CustomTransitionPage<void>(
      child: child,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    );

CustomTransitionPage<void> _slidePage(Widget child) => CustomTransitionPage<void>(
      child: child,
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween<Offset>(begin: const Offset(.12, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return SlideTransition(position: offset, child: FadeTransition(opacity: animation, child: child));
      },
    );
