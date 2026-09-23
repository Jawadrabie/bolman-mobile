import 'dart:async';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../core/datetime_utils.dart';
import '../../core/driver_trip_utils.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import '../shared/trip_tile.dart';

class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('driver.myTrips')),
          actions: [
            NotificationsAppBarButton(onPressed: () => context.push('/notifications')),
          ],
        ),
        body: BlocBuilder<DriverTripsCubit, BookingsState>(
          builder: (c, s) {
            final tripsCubit = c.read<DriverTripsCubit>();
            final active = tripsCubit.activeTrip;
            final upcoming = s.items
                .map((b) => b.trip)
                .whereType<Trip>()
                .where((t) => active == null || t.id != active.id)
                .toList();
            final grouped = _groupDriverTripsByDay(upcoming);
            return RefreshIndicator(
              onRefresh: tripsCubit.loadTrips,
              child: StateBox(
                loading: s.loading,
                error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
                empty: s.items.isEmpty && active == null,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (active != null) ...[
                      _ActiveTripCard(
                        trip: active,
                        onManifest: () => c.push('/driver/trip', extra: active),
                        onScan: () => c.push('/driver/scan', extra: active),
                      ),
                      if (grouped.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          c.tr('driver.upcomingTrips'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    for (final section in grouped) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          _driverTripDayLabel(c, section.day),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Theme.of(c).colorScheme.primary,
                          ),
                        ),
                      ),
                      ...section.trips.map(
                        (trip) => TripTile(trip, onTap: () => c.push('/driver/trip', extra: trip)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
}

List<({DateTime day, List<Trip> trips})> _groupDriverTripsByDay(List<Trip> trips) {
  final map = <DateTime, List<Trip>>{};
  for (final trip in trips) {
    final day = DateTime(trip.departure.year, trip.departure.month, trip.departure.day);
    (map[day] ??= []).add(trip);
  }
  final days = map.keys.toList()..sort();
  return [for (final day in days) (day: day, trips: map[day]!)];
}

String _driverTripDayLabel(BuildContext context, DateTime day) {
  final today = syriaToday();
  final tomorrow = today.add(const Duration(days: 1));
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return context.tr('passenger.quickToday');
  if (d == tomorrow) return context.tr('passenger.quickTomorrow');
  return formatSearchDate(day);
}

List<DriverManifestRow> sortManifestByRecentScan(List<DriverManifestRow> rows) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final aAt = a.boardedAt;
    final bAt = b.boardedAt;
    if (aAt != null && bAt != null) return bAt.compareTo(aAt);
    if (aAt != null) return -1;
    if (bAt != null) return 1;
    final aSeat = a.seatNumber ?? 9999;
    final bSeat = b.seatNumber ?? 9999;
    final seatCmp = aSeat.compareTo(bSeat);
    if (seatCmp != 0) return seatCmp;
    return a.passengerName.compareTo(b.passengerName);
  });
  return sorted;
}

bool _manifestMatchesSearch(DriverManifestRow row, String query) {
  final haystack = [
    row.passengerName,
    row.nationalId,
    row.passengerPhone,
    if (row.seatNumber != null) '${row.seatNumber}',
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}

class _ActiveTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onManifest;
  final VoidCallback onScan;

  const _ActiveTripCard({required this.trip, required this.onManifest, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('driver.currentTrip'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              Badge(text: l10n.t('driver.activeTrip'), color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${trip.originName} ${l10n.t('common.routeArrow')} ${trip.destinationName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(formatDateTime(trip.departure, l10n.languageCode)),
          const SizedBox(height: 6),
          Text(
            context.tr('driver.currentTripHint'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(context.tr('driver.scanForTrip')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManifest,
                  icon: const Icon(Icons.people),
                  label: Text(context.tr('driver.viewManifest')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DriverTripDetailsScreen extends StatefulWidget {
  final Trip trip;
  const DriverTripDetailsScreen({super.key, required this.trip});

  @override
  State<DriverTripDetailsScreen> createState() => _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen> {
  final repo = DriverRepo();
  final tripsRepo = TripsRepo();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool completing = false;
  bool loading = true;
  bool _searchOpen = false;
  String? error;
  String _searchQuery = '';
  List<DriverManifestRow> manifest = [];
  List<TripStop> stops = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus || !_searchOpen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchOpen && !_searchFocusNode.hasFocus) {
          _closeSearch();
        }
      });
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _closeSearch() {
    if (!_searchOpen) return;
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchOpen = false;
    });
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        repo.manifest(widget.trip.id),
        tripsRepo.stops(widget.trip.id),
      ]);
      if (!mounted) return;
      setState(() {
        manifest = sortManifestByRecentScan(results[0] as List<DriverManifestRow>);
        stops = results[1] as List<TripStop>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = mapError(e, L10n.of(context));
        loading = false;
      });
    }
  }

  int get _boardedCount => manifest.where((r) => r.ticketStatus == 'boarded' || r.ticketStatus == 'completed').length;

  List<DriverManifestRow> get _visibleManifest {
    if (_searchQuery.isEmpty) return manifest;
    return manifest.where((r) => _manifestMatchesSearch(r, _searchQuery)).toList();
  }

  Future<void> _openScan() async {
    await context.push('/driver/scan', extra: widget.trip);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final canComplete = widget.trip.status == 'active' || widget.trip.status == 'scheduled';
    final visible = _visibleManifest;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('driver.manifest')),
        leading: const BackButton(),
        actions: [

          if (manifest.isNotEmpty)
            IconButton(
              onPressed: () {
                if (_searchOpen) {
                  _closeSearch();
                } else {
                  setState(() => _searchOpen = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _searchFocusNode.requestFocus();
                  });
                }
              },
              icon: Icon(_searchOpen ? Icons.close : Icons.search),
              tooltip: context.tr('common.search'),
            ),
        ],
        bottom: _searchOpen && manifest.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: context.tr('driver.manifestSearch'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: GestureDetector(
        onTap: _searchOpen ? _closeSearch : null,
        behavior: HitTestBehavior.translucent,
        child: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (scaffoldCtx) => StateBox(
          loading: loading,
          error: error,
          empty: !loading && manifest.isEmpty,
          child: ListView(
            padding: const EdgeInsets.all(18),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _ManifestTripHeader(
                trip: widget.trip,
                boardedCount: _boardedCount,
                totalPassengers: manifest.length,
                canComplete: canComplete,
                completing: completing,
                onScan: _openScan,
                onComplete: completing
                    ? null
                    : () async {
                        final router = GoRouter.of(context);
                        final tripsCubit = scaffoldCtx.read<DriverTripsCubit>();
                        setState(() => completing = true);
                        try {
                          await repo.completeTrip(widget.trip.id);
                          if (!scaffoldCtx.mounted) return;
                          showAppSnack(scaffoldCtx, l10n.t('driver.completeSuccess'), type: AppSnackType.success);
                          await tripsCubit.loadTrips();
                          router.pop();
                        } catch (e) {
                          if (!scaffoldCtx.mounted) return;
                          showAppSnack(scaffoldCtx, mapError(e, l10n), type: AppSnackType.error);
                        } finally {
                          if (mounted) setState(() => completing = false);
                        }
                      },
              ),
              if (stops.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DriverRouteCard(stops: stops),
              ],
              const SizedBox(height: 8),
              if (manifest.isNotEmpty && visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    context.tr('driver.manifestNoResults'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55)),
                  ),
                ),
              ...visible.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ManifestPassengerCard(row: row),
                ),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }
}

class _ManifestTripHeader extends StatelessWidget {
  final Trip trip;
  final int boardedCount;
  final int totalPassengers;
  final bool canComplete;
  final bool completing;
  final VoidCallback onScan;
  final VoidCallback? onComplete;

  const _ManifestTripHeader({
    required this.trip,
    required this.boardedCount,
    required this.totalPassengers,
    required this.canComplete,
    required this.completing,
    required this.onScan,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final progress = totalPassengers == 0 ? 0.0 : boardedCount / totalPassengers;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dark
              ? [AppColors.primary.withValues(alpha: .18), AppColors.deepPurple.withValues(alpha: .12)]
              : [AppColors.softAccent, Colors.white],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: dark ? .28 : .18)),
        boxShadow: AppShadows.subtle(AppColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (trip.status == 'active')
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Badge(text: l10n.t('driver.activeTrip'), color: AppColors.primary),
                  ),
                const Spacer(),
                if (trip.busNumber != null && trip.busNumber!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_outlined, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(trip.busNumber!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ManifestCityLabel(name: trip.originName, alignEnd: true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.hero,
                      boxShadow: AppShadows.subtle(AppColors.primary),
                    ),
                    child: Center(
                      child: Text(
                        l10n.t('common.routeArrow'),
                        style: TextStyle(color: Colors.white.withValues(alpha: .95), fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _ManifestCityLabel(name: trip.destinationName, alignEnd: false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatDateTime(trip.departure, l10n.languageCode),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: .65),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (totalPassengers > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: .12),
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('driver.boardedCount', {
                      'boarded': '$boardedCount',
                      'total': '$totalPassengers',
                    }),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(context.tr('driver.scanForTrip')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                if (canComplete && onComplete != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: completing ? null : onComplete,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: .25)),
                      ),
                      child: completing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.tr('driver.completeTrip'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManifestCityLabel extends StatelessWidget {
  final String name;
  final bool alignEnd;

  const _ManifestCityLabel({required this.name, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16,
          color: theme.colorScheme.primary.withValues(alpha: .8),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _ManifestPassengerCard extends StatelessWidget {
  final DriverManifestRow row;

  const _ManifestPassengerCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final boarded = row.ticketStatus == 'boarded' || row.ticketStatus == 'completed';
    final phone = row.passengerPhone;
    final nationalId = row.nationalId;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: boarded ? const Color(0xFF34D399).withValues(alpha: .45) : theme.dividerColor.withValues(alpha: .45),
        ),
        boxShadow: AppShadows.subtle(boarded ? const Color(0xFF34D399) : AppColors.primary),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: boarded ? .18 : .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  context.tr('driver.seatLabel'),
                  style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: .55), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.seatNumber ?? '—'}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(row.passengerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    if (boarded) const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                _ManifestInfoRow(
                  icon: Icons.phone_outlined,
                  label: context.tr('passenger.phone'),
                  value: phone ?? '—',
                ),
                const SizedBox(height: 4),
                _ManifestInfoRow(
                  icon: Icons.badge_outlined,
                  label: context.tr('passenger.nationalId'),
                  value: nationalId ?? '—',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusBadge(row.ticketStatus),
                    if (row.boardedAt != null)
                      Text(
                        formatDateTime(row.boardedAt!, l10n.languageCode),
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: .55)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManifestInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ManifestInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary.withValues(alpha: .75)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .55), fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverRouteCard extends StatelessWidget {
  final List<TripStop> stops;
  const _DriverRouteCard({required this.stops});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final sorted = List<TripStop>.from(stops)..sort((a, b) => a.order.compareTo(b.order));

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .45)),
        boxShadow: AppShadows.subtle(AppColors.primary),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(context.tr('driver.routeStops'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;
            final isLast = index == sorted.length - 1;
            final isRest = stop.stopType == 'rest_stop';
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRest ? AppColors.warning : theme.colorScheme.primary,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .25), blurRadius: 4),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: theme.dividerColor.withValues(alpha: .6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          if (stop.boarding || stop.dropoff)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                [
                                  if (stop.boarding) context.tr('common.boarding'),
                                  if (stop.dropoff) context.tr('common.dropoff'),
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary.withValues(alpha: .8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  final Trip? trip;

  const ScanScreen({super.key, this.trip});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Ticket QR is the only barcode we ever want here; narrowing the format set keeps MLKit from
  // spending each frame probing the ~12 other symbologies, which is what made holding a ticket
  // up to the camera feel like nothing was being detected.
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  final _qrCubit = QrCubit();
  bool _scanLocked = false;
  Trip? _scanContextTrip;

  @override
  void initState() {
    super.initState();
    _scanContextTrip = widget.trip;
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip != null) _scanContextTrip = widget.trip;
  }

  /// The trip shown in the banner: the one the driver opened this screen for, or -- when they
  /// just tapped the Scan tab -- our best guess at what they are boarding right now.
  Trip? _scanTrip(DriverTripsCubit cubit) =>
      _scanContextTrip ?? resolveDriverScanContextTrip(
        null,
        activeTrip: cubit.activeTrip,
        upcoming: cubit.state.items.map((b) => b.trip).whereType<Trip>(),
      );

  /// The trip the scan is *restricted* to, which is only ever one the driver picked deliberately
  /// (the active-trip card, or a trip's own page). A guessed trip must never become the filter:
  /// scan_ticket_qr treats p_expected_trip_id as a hard reject, so passing a guess made every
  /// ticket for the driver's other assigned trips come back as "هذه التذكرة لرحلة أخرى". With no
  /// explicit choice we send null and let the function's own driver-assignment check authorize,
  /// which is the rule that actually matters.
  String? get _expectedTripId => _scanContextTrip?.id;

  @override
  void dispose() {
    unawaited(_qrCubit.close());
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  // The camera is deliberately left running while a scan is in flight: `_scanLocked` already
  // gates onDetect, and stop()/start() round-trips on mobile_scanner 5.x frequently come back
  // with a dead preview, which left the driver staring at a frozen frame that never scanned again.
  void _resumeScanner() {
    if (!mounted || !_scanLocked) return;
    setState(() => _scanLocked = false);
  }

  Future<void> _handleCode(String code, Trip? scanTrip) async {
    if (_scanLocked || code.trim().isEmpty || !mounted) return;
    setState(() => _scanLocked = true);

    final res = await _qrCubit.scan(code, expectedTripId: _expectedTripId);
    if (!mounted || res == null) {
      _resumeScanner();
      return;
    }
    _showScanResult(res, scanTrip);
  }

  void _showScanResult(ScanResult r, Trip? scanTrip) {
    if (!mounted) return;
    if (r.valid) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ScanResultSheet(
        result: r,
        scanTrip: scanTrip,
        onManifest: scanTrip == null
            ? null
            : () {
                Navigator.pop(sheetCtx);
                context.push('/driver/trip', extra: scanTrip);
              },
        onContinue: () => Navigator.pop(sheetCtx),
      ),
    ).then((_) {
      if (!mounted) return;
      _qrCubit.clear();
      if (r.valid) context.read<DriverTripsCubit>().loadTrips();
      _resumeScanner();
    });
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<DriverTripsCubit, BookingsState>(
        builder: (ctx, _) {
          final scanTrip = _scanTrip(ctx.read<DriverTripsCubit>());
          return Scaffold(
            appBar: AppBar(
              title: Text(context.tr('driver.scanTitle')),
              actions: [
                if (scanTrip != null)
                  TextButton(
                    onPressed: () => context.push('/driver/trip', extra: scanTrip),
                    child: Text(context.tr('driver.viewManifest')),
                  ),
              ],
            ),
            body: Column(
              children: [
                if (scanTrip != null) _ScanTripBanner(trip: scanTrip),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        // A denied camera permission or a busy camera used to render as a plain
                        // black rectangle, which is indistinguishable from "the scanner just
                        // isn't picking anything up". Surface the reason instead.
                        errorBuilder: (errCtx, error, _) => _ScanCameraError(error: error),
                        onDetect: (cap) {
                          // A frame can carry several candidates (and a rawValue can be null when
                          // only raw bytes decoded), so take the first one that actually has text
                          // rather than assuming it is barcodes.first.
                          for (final barcode in cap.barcodes) {
                            final code = barcode.rawValue;
                            if (code != null && code.trim().isNotEmpty) {
                              _handleCode(code, scanTrip);
                              return;
                            }
                          }
                        },
                      ),
                      if (_scanLocked)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: .35),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: TextField(
                    enabled: !_scanLocked,
                    decoration: InputDecoration(labelText: context.tr('driver.scanManualHint')),
                    onSubmitted: (v) => _handleCode(v.trim(), scanTrip),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _ScanCameraError extends StatelessWidget {
  final MobileScannerException error;

  const _ScanCameraError({required this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final detail = error.errorDetails?.message?.trim();

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t(denied ? 'driver.scanCameraDenied' : 'driver.scanCameraError'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              if (detail != null && detail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.t('driver.scanManualFallback'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanTripBanner extends StatelessWidget {
  final Trip trip;

  const _ScanTripBanner({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_bus, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('driver.scanningFor'),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55)),
                  ),
                  Text(
                    '${trip.originName} ${l10n.t('common.routeArrow')} ${trip.destinationName}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    formatDateTime(trip.departure, l10n.languageCode),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6)),
                  ),
                ],
              ),
            ),
            if (trip.status == 'active')
              Badge(text: l10n.t('driver.activeTrip'), color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ScanResultSheet extends StatelessWidget {
  final ScanResult result;
  final Trip? scanTrip;
  final VoidCallback onContinue;
  final VoidCallback? onManifest;

  const _ScanResultSheet({
    required this.result,
    required this.scanTrip,
    required this.onContinue,
    this.onManifest,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final visual = _scanVisual(result, l10n);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: visual.color.withValues(alpha: .25)),
          boxShadow: [
            BoxShadow(color: visual.color.withValues(alpha: .15), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [visual.color.withValues(alpha: .22), visual.color.withValues(alpha: .04)],
                  ),
                  border: Border.all(color: visual.color.withValues(alpha: .35)),
                ),
                child: Icon(visual.icon, size: 40, color: visual.color),
              ),
              const SizedBox(height: 16),
              Text(
                visual.title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                result.message.isNotEmpty ? result.message : visual.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .7),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (result.passengerName != null && result.passengerName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${l10n.t('driver.scanPassenger')}: ${result.passengerName}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ScanInfoChip(
                    icon: Icons.confirmation_number_outlined,
                    label: '${l10n.t('driver.scanType')}: ${result.ticketType == 'group' ? l10n.t('ticketMode.group') : l10n.t('ticketMode.individual')}',
                  ),
                  if (result.passengerCount > 0)
                    _ScanInfoChip(
                      icon: Icons.people_outline,
                      label: '${l10n.t('driver.scanPassengers')}: ${result.passengerCount}',
                    ),
                  _ScanInfoChip(
                    icon: Icons.info_outline,
                    label: l10n.status(result.scanResult),
                  ),
                ],
              ),
              if (result.ticketType == 'group' && result.valid) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.t('driver.groupScanHint'),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: .55)),
                  textAlign: TextAlign.center,
                ),
              ],
              if (result.ticketType == 'individual' && result.valid) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.t('driver.individualScanHint'),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: .55)),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              if (result.valid && onManifest != null) ...[
                FilledButton.icon(
                  onPressed: onManifest,
                  icon: const Icon(Icons.people),
                  label: Text(l10n.t('driver.openManifestAfterScan')),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: onContinue,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(l10n.t(result.valid ? 'driver.scanContinue' : 'common.close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ScanInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

({IconData icon, Color color, String title, String body}) _scanVisual(ScanResult r, L10n l10n) {
  switch (r.scanResult) {
    case 'valid':
      return (
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF34D399),
        title: l10n.t('driver.scanSuccessTitle'),
        body: l10n.t('driver.scanSuccessBody'),
      );
    case 'already_boarded':
      return (
        icon: Icons.history_rounded,
        color: AppColors.warning,
        title: l10n.t('driver.scanAlreadyUsedTitle'),
        body: l10n.t('driver.scanAlreadyUsedBody'),
      );
    case 'cancelled':
      return (
        icon: Icons.block_rounded,
        color: AppColors.danger,
        title: l10n.t('driver.scanCancelledTitle'),
        body: l10n.t('driver.scanCancelledBody'),
      );
    default:
      return (
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
        title: l10n.t('driver.scanInvalidTitle'),
        body: l10n.t('driver.scanRejectedTitle'),
      );
  }
}
