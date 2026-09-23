import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../shared/formatters.dart';

enum TripSortMode { cheapest, soonest }

List<Trip> sortTripsByDeparture(List<Trip> trips) {
  final sorted = [...trips]..sort((a, b) => a.departure.compareTo(b.departure));
  return sorted;
}

List<Trip> sortTripsByPrice(List<Trip> trips) {
  final sorted = [...trips]..sort((a, b) {
        final priceCmp = a.finalPrice.compareTo(b.finalPrice);
        if (priceCmp != 0) return priceCmp;
        return a.departure.compareTo(b.departure);
      });
  return sorted;
}

List<Trip> applyTripSort(List<Trip> trips, TripSortMode mode) =>
    mode == TripSortMode.cheapest ? sortTripsByPrice(trips) : sortTripsByDeparture(trips);

String? cheapestTripId(List<Trip> trips) {
  if (trips.length < 2) return null;
  final sorted = sortTripsByPrice(trips);
  return sorted.first.id;
}

BoxDecoration tripCardDecoration(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? AppColors.darkCard : Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: Border.all(color: dark ? AppColors.borderDark : AppColors.borderLight),
    boxShadow: dark ? null : AppShadows.subtle(AppColors.primary),
  );
}

Color tripMutedText(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: darkAlpha(context));

double darkAlpha(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? .72 : .62;

class TripSuggestionCard extends StatelessWidget {
  final Trip trip;
  final bool showCountdown;

  const TripSuggestionCard(this.trip, {super.key, this.showCountdown = false});

  static const double cardWidth = 248;
  static const double cardHeight = 148;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final diff = trip.departure.difference(DateTime.now());
    String? countdown;
    if (showCountdown && !diff.isNegative) {
      if (diff.inHours < 24) {
        countdown = l10n.t('passenger.inHours', {'hours': '${diff.inHours}'});
      } else {
        countdown = l10n.t('passenger.inDays', {'days': '${diff.inDays}'});
      }
    }

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/trip', extra: trip),
          child: Ink(
            decoration: tripCardDecoration(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Row(
                children: [
                  Container(
                    width: 78,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: dark
                            ? [AppColors.primary.withValues(alpha: .95), AppColors.deepPurple.withValues(alpha: .95)]
                            : AppGradients.hero.colors,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatHomeCardTime(trip.departure),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatHomeCardDate(trip.departure),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .88),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.directions_bus_filled_rounded,
                          color: Colors.white.withValues(alpha: .75),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  trip.companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                              if (trip.isOffer)
                                Badge(text: l10n.t('passenger.offerBadge'), color: AppColors.accent),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _CompactRoute(trip: trip),
                          const Spacer(),
                          Row(
                            children: [
                              if (countdown != null) ...[
                                Flexible(
                                  child: Badge(text: countdown, color: AppColors.primary),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                formatMoney(trip.finalPrice, l10n),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class TripTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final bool highlightBestPrice;

  const TripTile(this.trip, {super.key, this.onTap, this.highlightBestPrice = false});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = formatTripDuration(trip.departure, trip.arrival, l10n.languageCode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap ?? () => context.push('/trip', extra: trip),
        child: Ink(
          decoration: tripCardDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: dark
                          ? [
                              AppColors.primary.withValues(alpha: .22),
                              AppColors.deepPurple.withValues(alpha: .12),
                            ]
                          : [
                              AppColors.primary.withValues(alpha: .10),
                              AppColors.deepPurple.withValues(alpha: .05),
                            ],
                    ),
                  ),
                  child: Hero(
                    tag: 'trip-${trip.id}-company',
                    child: Material(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: dark ? .25 : .12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              Icons.directions_bus_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              trip.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          if (trip.isOffer) Badge(text: l10n.t('passenger.offerBadge'), color: AppColors.accent),
                          if (highlightBestPrice)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Badge(text: l10n.t('passenger.bestPrice'), color: AppColors.success),
                            ),
                          if (trip.status == 'active')
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Badge(text: l10n.t('driver.activeTrip'), color: AppColors.primary),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'trip-${trip.id}-route',
                        child: Material(
                          color: Colors.transparent,
                          child: _RouteTimeline(trip: trip),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _MetaChip(
                            icon: Icons.calendar_today_rounded,
                            label: formatShortDate(trip.departure),
                          ),
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: l10n.t('passenger.departureTimeChip', {
                              'time': formatHomeCardTime(trip.departure),
                            }),
                          ),
                          _MetaChip(icon: Icons.timelapse_rounded, label: duration),
                          if (trip.availableSeats != null)
                            _MetaChip(
                              icon: Icons.event_seat_rounded,
                              label: '${trip.availableSeats}',
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.t('passenger.ticketPrice'),
                              style: TextStyle(fontSize: 12, color: tripMutedText(context), fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (trip.isOffer && trip.offerPrice != null && trip.offerPrice! < trip.price) ...[
                            Text(
                              formatMoney(trip.price, l10n),
                              style: TextStyle(
                                color: tripMutedText(context),
                                decoration: TextDecoration.lineThrough,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            formatMoney(trip.finalPrice, l10n),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: tripMutedText(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactRoute extends StatelessWidget {
  final Trip trip;

  const _CompactRoute({required this.trip});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  trip.originName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 10,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .25),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.place_rounded, size: 12, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  trip.destinationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      );
}

class _RouteTimeline extends StatelessWidget {
  final Trip trip;

  const _RouteTimeline({required this.trip});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(Icons.trip_origin_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
              Container(
                width: 2,
                height: 22,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .22),
              ),
              Icon(Icons.place_rounded, size: 16, color: Theme.of(context).colorScheme.secondary),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.originName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 18),
                Text(
                  trip.destinationName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tripMutedText(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tripMutedText(context), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String formatShortDate(DateTime d, [String? locale]) =>
    DateFormat('yyyy/MM/dd', westernDigitsLocale).format(d);

String formatCompactDateTime(DateTime d, [String? locale]) =>
    DateFormat('dd/MM HH:mm', westernDigitsLocale).format(d);
