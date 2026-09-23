import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../cubits.dart';

/// Shared passenger cubits (search state survives /home → /results navigation).
class PassengerScope extends StatelessWidget {
  final Widget child;

  const PassengerScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SearchCubit()..init()),
          BlocProvider(create: (_) => BookingsCubit()..load()),
          BlocProvider(create: (_) => WalletCubit()..load()),
        ],
        child: PassengerShell(child: child),
      );
}

class PassengerShell extends StatelessWidget {
  final Widget child;

  const PassengerShell({super.key, required this.child});

  static const _tabPaths = ['/home', '/bookings', '/wallet', '/profile'];

  @override
  Widget build(BuildContext context) {
    final p = GoRouterState.of(context).uri.path;
    final tabIndex = p == '/bookings'
        ? 1
        : p.startsWith('/wallet')
            ? 2
            : p.startsWith('/profile')
                ? 3
                : p == '/home'
                    ? 0
                    : -1;
    final showNav = tabIndex >= 0;
    final navIndex = tabIndex < 0 ? 0 : tabIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SafeArea(
                key: ValueKey<int>(navIndex),
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: navIndex,
                  onDestinationSelected: (x) {
                    context.go(_tabPaths[x]);
                    if (x == 1) context.read<BookingsCubit>().load();
                    if (x == 2) context.read<WalletCubit>().load();
                  },
                  backgroundColor: Colors.transparent,
                  indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                  destinations: [
                    NavigationDestination(icon: const Icon(Icons.home), label: context.tr('passenger.home')),
                    NavigationDestination(icon: const Icon(Icons.confirmation_number), label: context.tr('passenger.bookings')),
                    NavigationDestination(icon: const Icon(Icons.wallet), label: context.tr('passenger.wallet')),
                    NavigationDestination(icon: const Icon(Icons.person_outline), label: context.tr('passenger.profile')),
                  ],
                ),
              ),
            ))
          : null,
    );
  }

}

class DriverShell extends StatelessWidget {
  final Widget child;

  const DriverShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = GoRouterState.of(context).uri.path;
    final i = p.contains('/driver/scan')
        ? 1
        : p.contains('/driver/profile')
            ? 2
            : 0;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DriverTripsCubit()..loadTrips()),
      ],
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.route), label: context.tr('driver.myTrips')),
            NavigationDestination(icon: const Icon(Icons.qr_code_scanner), label: context.tr('driver.scanQr')),
            NavigationDestination(icon: const Icon(Icons.person_outline), label: context.tr('passenger.profile')),
          ],
          onDestinationSelected: (idx) {
            switch (idx) {
              case 0:
                context.go('/driver');
              case 1:
                // Deliberately no `extra`. A trip passed here becomes p_expected_trip_id, which
                // scan_ticket_qr uses to *reject* tickets from any other trip -- so guessing one
                // on the driver's behalf (this used to hand over the nearest upcoming trip) locked
                // the scanner onto it and bounced every valid ticket for their other assigned
                // trips. ScanScreen still infers a trip for the banner; it just no longer filters
                // on a guess. Only the active-trip card and a trip's own page pass a real choice.
                context.go('/driver/scan');
              case 2:
                context.go('/driver/profile');
            }
          },
        ),
      ),
    );
  }
}
