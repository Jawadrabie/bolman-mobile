import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import 'formatters.dart';
import 'trip_tile.dart';

Color bookingStatusColor(String status) {
  switch (status) {
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.danger;
    case 'pending':
      return AppColors.warning;
    case 'partially_boarded':
    case 'boarded':
      return AppColors.info;
    default:
      return AppColors.primary;
  }
}

String? bookingStatusHint(L10n l10n, String status) {
  final key = 'passenger.statusHint.$status';
  final hint = l10n.t(key);
  return hint == key ? null : hint;
}

bool bookingHasTicket(String status) =>
    status == 'confirmed' ||
    status == 'partially_boarded' ||
    status == 'boarded' ||
    status == 'completed';

bool isActiveBookingStatus(String status) =>
    status == 'pending' ||
    status == 'confirmed' ||
    status == 'partially_boarded' ||
    status == 'boarded';

class BookingCard extends StatelessWidget {
  final BookingSummary booking;
  final VoidCallback? onRate;

  const BookingCard({super.key, required this.booking, this.onRate});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final trip = booking.trip;
    final statusColor = bookingStatusColor(booking.status);
    final statusHint = bookingStatusHint(l10n, booking.status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = tripMutedText(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/bookings/${booking.id}'),
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
                                statusColor.withValues(alpha: .22),
                                AppColors.deepPurple.withValues(alpha: .10),
                              ]
                            : [
                                statusColor.withValues(alpha: .10),
                                AppColors.primary.withValues(alpha: .04),
                              ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: dark ? .28 : .14),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.confirmation_num_rounded,
                            size: 18,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip?.companyName ?? l10n.t('booking.details'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              Text(
                                l10n.t('passenger.bookedAt', {'date': formatCompactDateTime(booking.createdAt)}),
                                style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Badge(text: l10n.status(booking.status), color: statusColor),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (trip != null)
                          Text(
                            '${trip.originName} ${l10n.t('common.routeArrow')} ${trip.destinationName}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.25),
                          )
                        else
                          Text(
                            l10n.t('booking.details'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        if (statusHint != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            statusHint,
                            style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            if (trip != null)
                              _BookingMetaChip(
                                icon: Icons.calendar_today_rounded,
                                label: formatDateTime(trip.departure, l10n.languageCode),
                              ),
                            _BookingMetaChip(
                              icon: Icons.people_outline_rounded,
                              label: '${booking.count} ${l10n.t('passenger.passengersCount')}',
                            ),
                            if (booking.ticketMode == 'group')
                              _BookingMetaChip(
                                icon: Icons.qr_code_2_rounded,
                                label: l10n.t('ticketMode.group'),
                              )
                            else if (booking.ticketMode == 'individual')
                              _BookingMetaChip(
                                icon: Icons.qr_code_rounded,
                                label: l10n.t('ticketMode.individual'),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.t('passenger.total'),
                                    style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    formatMoney(booking.total, l10n),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (booking.status == 'completed' && booking.rating == null && onRate != null)
                              FilledButton.tonalIcon(
                                onPressed: onRate,
                                icon: const Icon(Icons.star_outline_rounded, size: 18),
                                label: Text(l10n.t('passenger.rate')),
                              )
                            else if (booking.rating != null)
                              starRatingRow(booking.rating!)
                            else if (bookingHasTicket(booking.status))
                              OutlinedButton.icon(
                                onPressed: () => context.push('/ticket/${booking.id}'),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                label: Text(l10n.t('passenger.viewTicket')),
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
      ),
    );
  }
}

class _BookingMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BookingMetaChip({required this.icon, required this.label});

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
