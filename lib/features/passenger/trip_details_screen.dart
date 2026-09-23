import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import 'booking_args.dart';

class TripDetailsScreen extends StatelessWidget {
  final Trip trip;
  const TripDetailsScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DetailsCubit()..load(trip.id),
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.tr('passenger.tripDetails')),
            leading: const BackButton(),
          ),

          bottomNavigationBar: BlocBuilder<DetailsCubit, DetailsState>(
            builder: (c, s) {
              if (s.loading || s.error != null) return const SizedBox.shrink();
              final repo = TripsRepo();
              var bookable = repo.resolveSegment(trip, s.stops);
              if (!bookable.hasSegment && s.stops.isEmpty) {
                return const SizedBox.shrink();
              }
              return SafeArea(
                minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      c.tr('passenger.bookingCtaHint'),
                      textAlign: TextAlign.center,
                      style: Theme.of(c).textTheme.bodySmall?.copyWith(
                            color: Theme.of(c).colorScheme.onSurface.withValues(alpha: .55),
                          ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () async {
                        var resolved = repo.resolveSegment(trip, s.stops);
                        if (!resolved.hasSegment) {
                          resolved = await repo.ensureSegment(trip);
                        }
                        if (!c.mounted) return;
                        if (!resolved.hasSegment) {
                          ScaffoldMessenger.of(c).showSnackBar(
                            SnackBar(content: Text(c.tr('passenger.segmentUnknown'))),
                          );
                          return;
                        }
                        c.push('/seats', extra: SeatsArgs(resolved));
                      },
                      child: Text(c.tr('passenger.startBooking')),
                    ),
                  ],
                ),
              );
            },
          ),
          body: BlocBuilder<DetailsCubit, DetailsState>(
            builder: (c, s) => StateBox(
              loading: s.loading,
              error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
              child: AnimationLimiter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    const AnimationConfiguration.staggeredList(
                      position: 0,
                      duration: Duration(milliseconds: 340),
                      child: FadeInAnimation(
                        child: SizedBox.shrink(),
                      ),
                    ),
                    _TripHero(trip: trip),
                    const SizedBox(height: 14),
                    _TripScheduleCard(trip: trip),
                    const SizedBox(height: 14),
                    _TripAmenitiesCard(trip: trip),
                    if (s.stops.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _TripRouteCard(trip: trip, stops: s.stops),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _TripHero extends StatelessWidget {
  final Trip trip;
  const _TripHero({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: AppGradients.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Hero(
                  tag: 'trip-${trip.id}-company',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      trip.companyName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
              ),
              if (trip.isOffer)
                Badge(text: l10n.t('passenger.offerBadge'), color: AppColors.accent),
            ],
          ),
          if (trip.isOffer && trip.offerTitle != null && trip.offerTitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trip.offerTitle!,
              style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Hero(
            tag: 'trip-${trip.id}-route',
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.trip_origin, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.originName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
                    child: Container(width: 2, height: 20, color: Colors.white24),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.destinationName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('passenger.ticketPrice'),
                      style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    if (trip.isOffer && trip.offerPrice != null && trip.offerPrice! < trip.price) ...[
                      Text(
                        formatMoney(trip.price, l10n),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .6),
                          decoration: TextDecoration.lineThrough,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      formatMoney(trip.finalPrice, l10n),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<double?>(
                      future: BookingRepo().companyAverageRating(trip.companyId),
                      builder: (context, snapshot) {
                        final avg = snapshot.data;
                        final label = avg == null
                            ? '${l10n.t('passenger.companyRating')}: ${l10n.t('passenger.noRatingYet')}'
                            : '${l10n.t('passenger.companyRating')}: ${avg.toStringAsFixed(1)}';
                        return Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(color: Colors.white.withValues(alpha: .88), fontWeight: FontWeight.w700),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (trip.availableSeats != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${trip.availableSeats}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                      ),
                      Text(
                        l10n.t('passenger.seatsLeft'),
                        style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripScheduleCard extends StatelessWidget {
  final Trip trip;
  const _TripScheduleCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final locale = l10n.languageCode;
    return AppCard(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: l10n.t('passenger.departure'),
            value: formatDateTime(trip.departure, locale),
          ),
          const Divider(height: 22),
          _InfoRow(
            icon: Icons.flag_rounded,
            label: l10n.t('passenger.arrival'),
            value: formatDateTime(trip.arrival, locale),
          ),
          const Divider(height: 22),
          _InfoRow(
            icon: Icons.timelapse_rounded,
            label: l10n.t('passenger.tripDuration'),
            value: formatTripDuration(trip.departure, trip.arrival, locale),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55), fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ],
      );
}

class _TripRouteCard extends StatelessWidget {
  final Trip trip;
  final List<TripStop> stops;

  const _TripRouteCard({required this.trip, required this.stops});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final sorted = List<TripStop>.from(stops)..sort((a, b) => a.order.compareTo(b.order));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('passenger.routeOverview'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            l10n.t('passenger.yourSegment'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...List.generate(sorted.length, (i) {
            final stop = sorted[i];
            final isLast = i == sorted.length - 1;
            final isRest = stop.stopType == 'rest_stop';
            final isSegmentStart = stop.id == trip.fromStopId;
            final isSegmentEnd = stop.id == trip.toStopId;
            final highlight = isSegmentStart || isSegmentEnd;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 220 + (i * 80)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: Opacity(opacity: value, child: child),
              ),
              child: _RouteStopRow(
                stop: stop,
                isLast: isLast,
                highlight: highlight,
                isRest: isRest,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TripAmenitiesCard extends StatelessWidget {
  final Trip trip;

  const _TripAmenitiesCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final amenities = <({IconData icon, String label})>[
      (icon: Icons.wifi, label: 'WiFi'),
      (icon: Icons.ac_unit_rounded, label: 'AC'),
      (icon: Icons.usb_rounded, label: 'USB'),
      (icon: Icons.event_seat_rounded, label: context.tr('passenger.availableSeats')),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('passenger.amenities'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: amenities
                  .map(
                    (amenity) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(amenity.icon, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              amenity.label,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopRow extends StatelessWidget {
  final TripStop stop;
  final bool isLast;
  final bool highlight;
  final bool isRest;

  const _RouteStopRow({
    required this.stop,
    required this.isLast,
    required this.highlight,
    required this.isRest,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final time = stop.departure ?? stop.arrival;
    final dotColor = highlight ? AppColors.primary : (isRest ? AppColors.accent : Theme.of(context).colorScheme.outline);
    final lineColor = highlight ? AppColors.primary.withValues(alpha: .35) : Theme.of(context).dividerColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: highlight ? 14 : 10,
                  height: highlight ? 14 : 10,
                  decoration: BoxDecoration(
                    color: highlight ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: highlight ? 0 : 2),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: lineColor)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isRest ? l10n.t('passenger.restStop') : stop.name,
                          style: TextStyle(
                            fontWeight: highlight ? FontWeight.w900 : FontWeight.w600,
                            color: isRest
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .65)
                                : null,
                          ),
                        ),
                      ),
                      if (isRest)
                        Icon(Icons.local_cafe_outlined, size: 16, color: AppColors.accent.withValues(alpha: .9))
                      else if (highlight)
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                  if (isRest && stop.name.isNotEmpty)
                    Text(
                      stop.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .5),
                      ),
                    ),
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatDateTime(time, l10n.languageCode),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .5),
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
  }
}
