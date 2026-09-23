import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';

/// UI strings follow ar/en, but dates, times, and amounts always use Western digits (0-9).
const westernDigitsLocale = 'en';

String formatDateTime(DateTime d, [String? locale]) =>
    DateFormat('yyyy/MM/dd HH:mm', westernDigitsLocale).format(d);

/// Home offer / nearest-trip cards — Western numerals.
String formatHomeCardDateTime(DateTime d) =>
    DateFormat('dd MMM yyyy · HH:mm', westernDigitsLocale).format(d);

/// Search bar & summaries — Western numerals (dd/MM/yyyy).
String formatSearchDate(DateTime d) => DateFormat('dd/MM/yyyy', westernDigitsLocale).format(d);

String formatHomeCardTime(DateTime d) => DateFormat('HH:mm', westernDigitsLocale).format(d);

String formatHomeCardDate(DateTime d) => DateFormat('dd MMM', westernDigitsLocale).format(d);

String formatTripDuration(DateTime departure, DateTime arrival, String locale) {
  final diff = arrival.difference(departure);
  if (diff.isNegative) return '—';
  final hours = diff.inHours;
  final minutes = diff.inMinutes % 60;
  if (locale == 'en') {
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
  if (hours > 0 && minutes > 0) return '$hours س $minutes د';
  if (hours > 0) return '$hours ساعة';
  return '$minutes دقيقة';
}

String formatNumber(num v) => NumberFormat.decimalPattern(westernDigitsLocale).format(v);

String formatMoney(num v, L10n l10n) =>
    '${formatNumber(v)} ${l10n.t('common.currency')}';

String mapError(Object e, L10n l10n) {
  final m = e.toString().toLowerCase();
  if (m.contains('profile_not_found')) return l10n.t('errors.profileNotFound');
  if (m.contains('no host specified in uri') || m.contains('supabase_not_configured')) {
    return l10n.t('errors.supabaseNotConfigured');
  }
  final network = m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('clientexception') ||
      (m.contains('connection') && m.contains('timed out')) ||
      (m.contains('connection') && m.contains('refused')) ||
      (m.contains('connection') && m.contains('error'));
  if (network) return l10n.t('errors.network');
  if (m.contains('insufficient_balance')) return l10n.t('errors.insufficientBalance');
  if (m.contains('authentication required')) return l10n.t('errors.authRequired');
  if (m.contains('invalid login credentials')) return l10n.t('errors.invalidCredentials');
  // Profile / password reset
  if (m.contains('role_change_not_allowed') || m.contains('status_change_not_allowed')) {
    return l10n.t('errors.privilegeChangeBlocked');
  }
  if (m.contains('avatar_url') && (m.contains('does not exist') || m.contains('column'))) {
    return l10n.t('errors.avatarColumnMissing');
  }
  if (m.contains('bucket not found') || m.contains('bucket_not_found')) {
    return l10n.t('errors.avatarBucketMissing');
  }
  if (m.contains('payload too large') || m.contains('exceeded the maximum allowed size')) {
    return l10n.t('errors.avatarTooLarge');
  }
  if (m.contains('users_phone_key') || (m.contains('duplicate key') && m.contains('phone'))) {
    return l10n.t('errors.phoneTaken');
  }
  if (m.contains('invalid_reset_code') ||
      m.contains('token has expired or is invalid') ||
      m.contains('otp_expired') ||
      m.contains('invalid or has expired')) {
    return l10n.t('errors.resetCodeInvalid');
  }
  if (m.contains('new password should be different')) return l10n.t('profile.errorSamePassword');
  if (m.contains('for security purposes') || m.contains('over_email_send_rate_limit')) {
    return l10n.t('errors.emailRateLimited');
  }
  if (m.contains('not available')) return l10n.t('errors.seatUnavailable');
  if (m.contains('bus_seat_id') && m.contains('ambiguous')) {
    return l10n.t('errors.lockSeatsRpcFix');
  }
  if (m.contains('not an active driver')) return l10n.t('errors.notActiveDriver');
  if (m.contains('driver_trip_manifest') && (m.contains('does not exist') || m.contains('42883'))) {
    return l10n.t('errors.rpcManifestMissing');
  }
  if (m.contains('complete_trip') && (m.contains('does not exist') || m.contains('42883'))) {
    return l10n.t('errors.rpcCompleteMissing');
  }
  if (m.contains('cancel_booking_with_refund') ||
      (m.contains('cancel') && m.contains('booking') && (m.contains('does not exist') || m.contains('42883')))) {
    return l10n.t('errors.rpcCancelMissing');
  }
  if (m.contains('modify_booking_before_cutoff') ||
      (m.contains('modify') && m.contains('booking') && (m.contains('does not exist') || m.contains('42883')))) {
    return l10n.t('errors.rpcModifyMissing');
  }
  if (m.contains('cutoff') || m.contains('one hour')) return l10n.t('errors.cutoff');
  final cleaned = e.toString().replaceAll('Exception:', '').trim();
  return cleaned.isEmpty ? l10n.t('errors.unexpected') : cleaned;
}

Future<int?> pickRating(BuildContext context) {
  final l10n = L10n.of(context);
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      int stars = 5;
      return StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(l10n.t('passenger.rateTrip')),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => set(() => stars = i + 1),
                icon: Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  color: Theme.of(ctx).colorScheme.primary,
                  size: 36,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.t('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, stars), child: Text(l10n.t('common.confirm'))),
          ],
        ),
      );
    },
  );
}

Widget starRatingRow(int value, {double size = 18}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (index) => Icon(
        index < value ? Icons.star_rounded : Icons.star_border_rounded,
        color: AppColors.accent,
        size: size,
      ),
    ),
  );
}

bool canCancelBooking(String status) => status == 'confirmed' || status == 'pending';

bool canModifyBooking(String status) => status == 'confirmed' || status == 'pending';

/// A booking whose payment never completed. Such a booking holds no seats and
/// no tickets, so it must be paid before it can be modified.
bool bookingNeedsPayment(String status, String paymentStatus) =>
    status == 'pending' || paymentStatus == 'pending' || paymentStatus == 'failed';
