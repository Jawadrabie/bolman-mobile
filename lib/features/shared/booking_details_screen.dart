import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import '../shared/pay_pending_dialog.dart';

class BookingDetailsScreen extends StatelessWidget {
  final String bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => BookingDetailsCubit()..load(bookingId),
        child: BlocConsumer<BookingDetailsCubit, BookingDetailsState>(
          listener: (c, s) {
            if (s.error != null) showAppSnack(c, mapError(s.error!, L10n.of(c)), type: AppSnackType.error);
            if (s.message == 'cancelled') {
              showAppSnack(c, c.tr('booking.cancelSuccess'), type: AppSnackType.success);
              c.pop();
            }
            if (s.message == 'paid') {
              showAppSnack(c, c.tr('booking.paySuccess'), type: AppSnackType.success);
            }
            if (s.message == 'modified') {
              showAppSnack(c, c.tr('booking.modifySuccess'), type: AppSnackType.success);
              c.read<BookingDetailsCubit>().load(bookingId);
            }
          },
          builder: (c, s) {
            final b = s.details;
            return Scaffold(
              appBar: AppBar(
                title: Text(c.tr('booking.details')),
                leading: const BackButton(),
                elevation: 0,
              ),
              bottomNavigationBar: b == null
                  ? null
                  : Container(
                      decoration: BoxDecoration(
                        color: Theme.of(c).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(c).dividerColor.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.qr_code_2, size: 20),
                                      label: Text(c.tr('passenger.viewTicket')),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => c.push('/ticket/${b.id}'),
                                    ),
                                  ),
                                  if (canCancelBooking(b.status)) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        icon: const Icon(Icons.cancel_outlined, size: 18),
                                        label: Text(c.tr('booking.cancel')),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.danger,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: s.actionLoading
                                            ? null
                                            : () async {
                                                final ok = await showDialog<bool>(
                                                  context: c,
                                                  builder: (ctx) => AlertDialog(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                    title: Text(c.tr('booking.cancelModalTitle')),
                                                    content: Text(c.tr('booking.cancelModalBody')),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(ctx, false),
                                                        child: Text(c.tr('common.cancel')),
                                                      ),
                                                      FilledButton(
                                                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        child: Text(c.tr('booking.confirmCancel')),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (ok == true && c.mounted) await c.read<BookingDetailsCubit>().cancel(b.id);
                                              },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (canModifyBooking(b.status)) ...[
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                                  label: Text(c.tr('booking.modify')),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: s.actionLoading
                                      ? null
                                      : () async {
                                          var booking = b;
                                          if (bookingNeedsPayment(b.status, b.paymentStatus)) {
                                            final wantsToPay = await showPayPendingDialog(c, b.total);
                                            if (!c.mounted) return;
                                            if (!wantsToPay) {
                                              showAppSnack(c, c.tr('booking.payFirstDeclined'), type: AppSnackType.info);
                                              return;
                                            }
                                            final paid = await c.read<BookingDetailsCubit>().payPending(b.id);
                                            if (!paid || !c.mounted) return;
                                            c.read<WalletCubit>().load();
                                            c.read<BookingsCubit>().load();
                                            // Seats and tickets only exist after payment, so modify must
                                            // start from the refreshed booking rather than the stale one.
                                            final refreshed = c.read<BookingDetailsCubit>().state.details;
                                            if (refreshed == null) return;
                                            booking = refreshed;
                                          }
                                          final updated = await c.push<bool>('/bookings/${booking.id}/modify', extra: booking);
                                          if (updated == true && c.mounted) {
                                            c.read<BookingDetailsCubit>().load(booking.id);
                                          }
                                        },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
              body: StateBox(
                loading: s.loading,
                error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
                empty: b == null,
                child: b == null
                    ? const SizedBox()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        children: [
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c.tr('booking.statusCard'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                    const Spacer(),
                                    Badge(
                                      text: b.ticketMode == 'group' ? c.tr('ticketMode.group') : c.tr('ticketMode.individual'),
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusBadge(b.status),
                                    StatusBadge(b.paymentStatus),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(c.tr('booking.commercial'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatMoney(b.total, c.l10n),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary),
                                    ),
                                    Text(
                                      '${b.count} ${c.tr('passenger.passengersCount')}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${c.tr('booking.createdAt')}: ${formatDateTime(b.createdAt, c.l10n.languageCode)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(c).colorScheme.onSurface.withValues(alpha: .6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (b.trip != null)
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_bus_outlined, size: 18, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(c.tr('booking.journey'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                      const Spacer(),
                                      Text(
                                        b.trip!.companyName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${b.trip!.originName} ${c.tr('common.routeArrow')} ${b.trip!.destinationName}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16, color: AppColors.mutedLight),
                                      const SizedBox(width: 6),
                                      Text(
                                        formatDateTime(b.trip!.departure, c.l10n.languageCode),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  if (b.seatNumbers.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.airline_seat_recline_normal, size: 16, color: AppColors.mutedLight),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${c.tr('passenger.seatsLabel')}: ${b.seatNumbers.join(', ')}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 20, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(c.tr('booking.passengers'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...b.passengers.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary.withValues(alpha: .1),
                                      child: const Icon(Icons.person, size: 18, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.phone ?? '-'} · ${p.nationalId}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(c).colorScheme.onSurface.withValues(alpha: .6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, size: 20, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(c.tr('booking.tickets'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...b.tickets.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.qr_code, size: 20, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (t.type == 'individual' && t.passengerName != null && t.passengerName!.isNotEmpty) t.passengerName,
                                              t.type == 'group' ? c.tr('ticketMode.group') : c.tr('ticketMode.individual'),
                                              c.trStatus(t.status),
                                            ].whereType<String>().join(' · '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(c).colorScheme.onSurface.withValues(alpha: .6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (b.status == 'completed' && b.rating == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.star_outline, size: 18),
                                label: Text(c.tr('passenger.rateTrip')),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () async {
                                  final stars = await pickRating(c);
                                  if (!c.mounted) return;
                                  if (stars != null) {
                                    await BookingRepo().rate(b.id, stars);
                                    if (c.mounted) c.read<BookingDetailsCubit>().load(b.id);
                                  }
                                },
                              ),
                            ),
                          if (b.rating != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: AppCard(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${c.tr('passenger.yourRating')}:', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    starRatingRow(b.rating!),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            );
          },
        ),
      );
}
