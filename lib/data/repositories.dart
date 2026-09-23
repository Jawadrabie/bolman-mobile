import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/driver_trip_utils.dart';
import 'models.dart';

class AuthRepo {
  Future<void> login(String email, String password) =>
      sb.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> registerPassenger({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) =>
      sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim(), 'phone': phone.trim(), 'role': 'passenger'},
      );

  Future<void> reset(String email) => sb.auth.resetPasswordForEmail(email.trim());
  Future<void> logout() => sb.auth.signOut();

  static const _profileColumns = 'id,full_name,email,phone,role,status,avatar_url';

  Future<Profile?> profile() async {
    final u = sb.auth.currentUser;
    if (u == null) return null;
    final d = await sb.from('users').select(_profileColumns).eq('id', u.id).maybeSingle();
    return d == null ? null : Profile.fromMap(Map<String, dynamic>.from(d));
  }

  // ---------------------------------------------------------------------------
  // Profile editing
  // ---------------------------------------------------------------------------

  /// Updates the editable columns only. Email stays owned by Supabase Auth, and
  /// role/status are rejected by the prevent_self_privilege_change trigger.
  Future<Profile> updateProfile({required String fullName, String? phone}) async {
    final u = sb.auth.currentUser;
    if (u == null) throw Exception('Authentication required');
    final trimmedPhone = phone?.trim();
    final d = await sb
        .from('users')
        .update({
          'full_name': fullName.trim(),
          'phone': trimmedPhone == null || trimmedPhone.isEmpty ? null : trimmedPhone,
        })
        .eq('id', u.id)
        .select(_profileColumns)
        .single();
    return Profile.fromMap(Map<String, dynamic>.from(d));
  }

  /// Uploads [bytes] to `avatars/<uid>/<timestamp>.<ext>` and stores the public
  /// URL on the user row. A fresh filename per upload avoids stale CDN caching.
  Future<Profile> uploadAvatar({required Uint8List bytes, required String fileExtension}) async {
    final u = sb.auth.currentUser;
    if (u == null) throw Exception('Authentication required');

    final ext = _normalizeImageExtension(fileExtension);
    final path = '${u.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = sb.storage.from(_avatarBucket);

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: _contentTypeFor(ext), upsert: true),
    );

    final publicUrl = storage.getPublicUrl(path);
    final d = await sb
        .from('users')
        .update({'avatar_url': publicUrl})
        .eq('id', u.id)
        .select(_profileColumns)
        .single();

    // Awaited on purpose: a detached prune from an earlier upload would still be
    // holding the previous `keep` value and would delete this new file.
    await _pruneOldAvatars(u.id, keep: path);

    return Profile.fromMap(Map<String, dynamic>.from(d));
  }

  Future<Profile> removeAvatar() async {
    final u = sb.auth.currentUser;
    if (u == null) throw Exception('Authentication required');
    final d = await sb
        .from('users')
        .update({'avatar_url': null})
        .eq('id', u.id)
        .select(_profileColumns)
        .single();
    await _pruneOldAvatars(u.id);
    return Profile.fromMap(Map<String, dynamic>.from(d));
  }

  static const _avatarBucket = 'avatars';

  Future<void> _pruneOldAvatars(String userId, {String? keep}) async {
    try {
      final storage = sb.storage.from(_avatarBucket);
      final files = await storage.list(path: userId);
      final stale = files
          .map((f) => '$userId/${f.name}')
          .where((p) => p != keep)
          .toList();
      if (stale.isNotEmpty) await storage.remove(stale);
    } catch (_) {
      // Cleanup is not worth failing the save over.
    }
  }

  String _normalizeImageExtension(String raw) {
    final ext = raw.replaceAll('.', '').trim().toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
  }

  String _contentTypeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  // ---------------------------------------------------------------------------
  // Password
  // ---------------------------------------------------------------------------

  /// Re-checks the current password before changing it — `updateUser` alone
  /// would let anyone holding an unlocked phone set a new password.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final email = sb.auth.currentUser?.email;
    if (email == null) throw Exception('Authentication required');
    await sb.auth.signInWithPassword(email: email, password: currentPassword);
    await sb.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Sends the recovery email (6-digit code and/or link, per the Supabase template).
  Future<void> sendPasswordResetCode(String email) => sb.auth.resetPasswordForEmail(email.trim());

  /// Verifies a recovery code and sets [newPassword].
  ///
  /// Accepts either the numeric `{{ .Token }}` from the email, or — so the flow
  /// works even with Supabase's default link-only template — the pasted reset
  /// link / raw token hash.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final input = code.trim();
    // Digits only, spaces/dashes tolerated because the email renders the code
    // letter-spaced. Supabase OTP length is configurable (6-10), so don't
    // hard-code 6.
    final compact = input.replaceAll(RegExp(r'[\s\-‐-―]'), '');

    if (RegExp(r'^\d{6,10}$').hasMatch(compact)) {
      await sb.auth.verifyOTP(type: OtpType.recovery, email: email.trim(), token: compact);
    } else {
      final hash = _extractTokenHash(input);
      if (hash == null) throw Exception('INVALID_RESET_CODE');
      await sb.auth.verifyOTP(type: OtpType.recovery, tokenHash: hash);
    }

    // verifyOTP already persisted a real session to secure storage. If setting
    // the password now fails, that session must go: otherwise the next launch
    // signs the user in with the OLD password still in force.
    try {
      await sb.auth.updateUser(UserAttributes(password: newPassword));
    } catch (_) {
      await sb.auth.signOut();
      rethrow;
    }
  }

  /// Pulls the recovery token out of a pasted Supabase verify link.
  String? _extractTokenHash(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.hasScheme) {
      for (final key in ['token', 'token_hash', 'confirmation_token']) {
        final v = uri.queryParameters[key]?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      final fragment = uri.fragment.trim();
      if (fragment.isNotEmpty) {
        final parsed = Uri.splitQueryString(fragment);
        for (final key in ['token', 'token_hash']) {
          final v = parsed[key]?.trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
      return null;
    }
    // A bare token hash pasted on its own.
    return RegExp(r'^[A-Za-z0-9_-]{16,}$').hasMatch(input) ? input : null;
  }
}

class RefRepo {
  Future<List<City>> cities() async {
    final d = await sb.from('cities').select('id,name').eq('is_active', true).order('name');
    return (d as List).map((e) => City.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}

class TripsRepo {
  Future<List<Trip>> search(String from, String to, DateTime date) async {
    final r = await sb.rpc('search_trips', params: {
      'p_origin_city_id': from,
      'p_destination_city_id': to,
      'p_travel_date': date.toIso8601String().substring(0, 10),
    });
    return (r as List).map((e) => Trip.fromSearch(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Trip>> offers() async {
    final d = await sb
        .from('trips')
        .select(
          '*,companies(name),buses(number_bus),origin_city:cities!trips_origin_city_id_fkey(name),destination_city:cities!trips_destination_city_id_fkey(name)',
        )
        .eq('status', 'scheduled')
        .eq('offer_is', true)
        .gte('departure_datetime', DateTime.now().toIso8601String())
        .order('departure_datetime')
        .limit(12);
    return _mapScheduledTrips(d);
  }

  /// Scheduled trips ordered by nearest departure (suggestions on home).
  Future<List<Trip>> upcoming({int limit = 50}) async {
    final d = await sb
        .from('trips')
        .select(
          '*,companies(name),buses(number_bus),origin_city:cities!trips_origin_city_id_fkey(name),destination_city:cities!trips_destination_city_id_fkey(name)',
        )
        .eq('status', 'scheduled')
        .gte('departure_datetime', DateTime.now().toIso8601String())
        .order('departure_datetime')
        .limit(limit);
    return _mapScheduledTrips(d);
  }

  /// Home/offers lists — segment IDs are resolved lazily on trip details / booking.
  List<Trip> _mapScheduledTrips(dynamic d) {
    final trips = (d as List).map((e) => Trip.fromTable(Map<String, dynamic>.from(e))).toList()
      ..sort((a, b) => a.departure.compareTo(b.departure));
    return trips;
  }

  /// Fills [Trip.fromStopId]/[toStopId] using an already-loaded route (e.g. trip details).
  Trip resolveSegment(Trip trip, List<TripStop> route) {
    if (trip.hasSegment) return trip;

    final cityStops = route.where((s) => s.stopType == 'city').toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (cityStops.isEmpty) return trip;

    final originId = _normId(trip.originCityId);
    final destId = _normId(trip.destinationCityId);
    TripStop? fromStop;
    TripStop? toStop;

    if (originId != null && destId != null) {
      for (final s in cityStops) {
        final cityId = _normId(s.cityId);
        if (cityId == originId && s.boarding) {
          if (fromStop == null || s.order < fromStop.order) fromStop = s;
        }
        if (cityId == destId && s.dropoff) {
          if (toStop == null || s.order > toStop.order) toStop = s;
        }
      }
      fromStop ??= _pickCityStop(cityStops, originId, pickMinOrder: true);
      toStop ??= _pickCityStop(cityStops, destId, pickMinOrder: false);
    }

    fromStop ??= cityStops.first;
    toStop ??= cityStops.last;
    if (fromStop.order >= toStop.order) return trip;
    return trip.withSegment(fromStopId: fromStop.id, toStopId: toStop.id);
  }

  /// Fills [Trip.fromStopId]/[toStopId] for offers and other rows loaded without search RPC.
  Future<Trip> ensureSegment(Trip trip) async {
    if (trip.hasSegment) return trip;
    return resolveSegment(trip, await stops(trip.id));
  }

  String? _normId(String? id) => id?.trim().toLowerCase();

  TripStop? _pickCityStop(List<TripStop> cityStops, String cityId, {required bool pickMinOrder}) {
    TripStop? picked;
    for (final s in cityStops) {
      if (_normId(s.cityId) != cityId) continue;
      if (picked == null) {
        picked = s;
        continue;
      }
      if (pickMinOrder ? s.order < picked.order : s.order > picked.order) picked = s;
    }
    return picked;
  }

  Future<List<TripStop>> stops(String tripId) async {
    final d = await sb
        .from('trip_stops')
        .select(
          'id,trip_id,stop_type,city_id,order_stop,time_arrival,time_departure,is_boarding_allowed,is_dropoff_allowed,cities(name),rest_stops(name)',
        )
        .eq('trip_id', tripId)
        .order('order_stop');
    return (d as List).map((e) => TripStop.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}

class SeatsRepo {
  Future<List<SeatStatus>> status(String trip, String from, String to) async {
    final r = await sb.rpc('get_seats_status_v2', params: {
      'p_trip_id': trip,
      'p_from_trip_stop_id': from,
      'p_to_trip_stop_id': to,
    });
    return (r as List).map((e) => SeatStatus.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> lock(String trip, String from, String to, List<String> seats) => sb.rpc('lock_seats', params: {
        'p_trip_id': trip,
        'p_from_trip_stop_id': from,
        'p_to_trip_stop_id': to,
        'p_bus_seat_ids': seats,
        'p_ttl_minutes': 5,
      });
}

class BookingRepo {
  Future<String> confirmWallet({
    required Trip trip,
    required String from,
    required String to,
    required List<String> seats,
    required List<PassengerDraft> passengers,
    required String ticketMode,
  }) async {
    final r = await sb.rpc('confirm_wallet_booking', params: {
      'p_trip_id': trip.id,
      'p_from_trip_stop_id': from,
      'p_to_trip_stop_id': to,
      'p_bus_seat_ids': seats,
      'p_passengers': passengers.map((e) => e.toJson()).toList(),
      'p_ticket_mode': ticketMode,
    });
    return r as String;
  }

  Future<List<BookingSummary>> mine() async {
    final u = sb.auth.currentUser;
    if (u == null) return [];
    // Filter by booker_user_id so Postgres uses idx_bookings_booker_user_id instead of
    // evaluating can_read_booking() on every row in the table (statement timeout).
    final d = await sb
        .from('bookings')
        .select('''
id,trip_id,from_trip_stop_id,to_trip_stop_id,count_passengers,payment_status,booking_status,price_total,ticket_mode,rating_value,created_at,
trips(id,company_id,bus_id,status,departure_datetime,expected_arrival_datetime,price,offer_is,price_offer,title_offer,origin_city:cities!trips_origin_city_id_fkey(name),destination_city:cities!trips_destination_city_id_fkey(name))
''')
        .eq('booker_user_id', u.id)
        .order('created_at', ascending: false);
    return (d as List).map((e) => BookingSummary.fromMap(Map<String, dynamic>.from(e))).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<BookingDetails> details(String id) async {
    final d = await sb.from('bookings').select('''
*, trip:trips(*, company:companies(name), bus:buses(number_bus), driver:drivers(id, user:users(full_name)), origin:cities!trips_origin_city_id_fkey(name), destination:cities!trips_destination_city_id_fkey(name)),
booking_passengers(*), booking_seats(*, seat:bus_seats(seat_number)), tickets(*, passenger:booking_passengers(full_name)), payments(*)
''').eq('id', id).single();
    return BookingDetails.fromMap(Map<String, dynamic>.from(d));
  }

  Future<void> cancel(String id) => sb.rpc('cancel_booking_with_refund', params: {'p_booking_id': id});

  /// Pays an unpaid (pending) booking from the wallet. The RPC assigns seats
  /// when the booking holds none, then issues its tickets.
  Future<void> payPending(String id) => sb.rpc('pay_pending_booking', params: {'p_booking_id': id});

  Future<void> modify({
    required String bookingId,
    required String from,
    required String to,
    required List<String> seatIds,
    required List<PassengerDraft> passengers,
    required String ticketMode,
  }) =>
      sb.rpc('modify_booking_before_cutoff', params: {
        'p_booking_id': bookingId,
        'p_from_trip_stop_id': from,
        'p_to_trip_stop_id': to,
        'p_bus_seat_ids': seatIds,
        'p_passengers': passengers.map((e) => e.toJson()).toList(),
        'p_ticket_mode': ticketMode,
      });

  Future<void> rate(String id, int stars) =>
      sb.rpc('rate_booking', params: {'p_booking_id': id, 'p_rating_value': stars});

  Future<double?> companyAverageRating(String companyId) async {
    final d = await sb
        .from('bookings')
        .select('rating_value, trip:trips!inner(company_id)')
        .eq('trip.company_id', companyId)
        .eq('booking_status', 'completed')
        .not('rating_value', 'is', null);
    final rows = d as List;
    if (rows.isEmpty) return null;
    final sum = rows.fold<double>(0, (total, row) => total + (row['rating_value'] as num).toDouble());
    return sum / rows.length;
  }

  Future<List<Ticket>> tickets(String bookingId) async {
    final d = await sb.from('tickets').select('*, passenger:booking_passengers(full_name)').eq('booking_id', bookingId).order('created_at');
    return (d as List).map((e) => Ticket.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}

class WalletRepo {
  Future<Wallet?> wallet() async {
    final u = sb.auth.currentUser;
    if (u == null) return null;
    final d = await sb.from('wallets').select('id,balance').eq('user_id', u.id).maybeSingle();
    return d == null ? null : Wallet.fromMap(Map<String, dynamic>.from(d));
  }

  Future<List<WalletTx>> txs(String walletId) async {
    final d = await sb
        .from('wallet_transactions')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false)
        .limit(100);
    return (d as List).map((e) => WalletTx.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}

class NotificationsRepo {
  Future<List<NotificationItem>> list() async {
    // Fetch all notifications and sort client-side by distance from now, because
    // PostgREST doesn't accept complex SQL functions in order().
    // This keeps both real notifications and seed data visible, with newest first.
    final d = await sb.from('notifications').select().limit(200);
    final items = (d as List)
        .map((e) => NotificationItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final now = DateTime.now();
    items.sort((a, b) {
      final aDiff = a.createdAt.difference(now).inSeconds.abs();
      final bDiff = b.createdAt.difference(now).inSeconds.abs();
      return aDiff.compareTo(bDiff);
    });

    return items.take(100).toList();
  }

  Future<void> read(String id) => sb.from('notifications').update({'is_read': true}).eq('id', id);

  Future<void> registerFcm(String token, String platform, String? deviceId) =>
      sb.rpc('register_fcm_token', params: {'p_token': token, 'p_platform': platform, 'p_device_id': deviceId});
}

class DriverRepo {
  static String? _manifestStr(dynamic v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  Future<String> driverId() async {
    final u = sb.auth.currentUser;
    if (u == null) throw Exception('Authentication required');
    final d = await sb.from('drivers').select('id').eq('user_id', u.id).eq('status', 'active').single();
    return d['id'];
  }

  Future<List<Trip>> trips() async {
    final id = await driverId();
    final d = await sb
        .from('trips')
        .select(
          '*,companies(name),buses(number_bus),origin_city:cities!trips_origin_city_id_fkey(name),destination_city:cities!trips_destination_city_id_fkey(name)',
        )
        .eq('driver_id', id)
        .inFilter('status', ['scheduled', 'active'])
        .order('departure_datetime');
    final all = (d as List).map((e) => Trip.fromTable(Map<String, dynamic>.from(e))).toList();
    return all.where(isDriverTripUpcoming).toList()
      ..sort((a, b) => a.departure.compareTo(b.departure));
  }

  Future<List<Trip>> pastTrips({DateTime? from, DateTime? to}) async {
    final id = await driverId();
    var query = sb
        .from('trips')
        .select(
          '*,companies(name),buses(number_bus),origin_city:cities!trips_origin_city_id_fkey(name),destination_city:cities!trips_destination_city_id_fkey(name)',
        )
        .eq('driver_id', id)
        .eq('status', 'completed');
    if (from != null) query = query.gte('departure_datetime', from.toUtc().toIso8601String());
    if (to != null) query = query.lte('departure_datetime', to.toUtc().toIso8601String());
    final d = await query.order('departure_datetime', ascending: false);
    return (d as List).map((e) => Trip.fromTable(Map<String, dynamic>.from(e))).toList();
  }

  Future<Trip?> currentTrip() async => pickDriverCurrentTrip(await trips());

  Future<List<DriverManifestRow>> manifest(String tripId) async {
    final r = await sb.rpc('driver_trip_manifest', params: {'p_trip_id': tripId});
    final rows = (r as List).map((e) => DriverManifestRow.fromMap(Map<String, dynamic>.from(e))).toList();
    return _enrichManifestContacts(tripId, rows);
  }

  Future<List<DriverManifestRow>> _enrichManifestContacts(String tripId, List<DriverManifestRow> rows) async {
    if (rows.isEmpty || !rows.any((r) => r.passengerPhone == null || r.nationalId == null)) return rows;
    try {
      final d = await sb
          .from('bookings')
          .select('booking_passengers(id, phone, national_id)')
          .eq('trip_id', tripId)
          .eq('payment_status', 'success')
          .inFilter('booking_status', ['confirmed', 'partially_boarded', 'boarded', 'completed']);
      final contacts = <String, ({String? phone, String? nationalId})>{};
      for (final booking in d as List) {
        final passengers = booking['booking_passengers'];
        if (passengers is! List) continue;
        for (final raw in passengers) {
          final p = Map<String, dynamic>.from(raw as Map);
          final id = p['id']?.toString();
          if (id == null) continue;
          contacts[id] = (
            phone: _manifestStr(p['phone']),
            nationalId: _manifestStr(p['national_id']),
          );
        }
      }
      return rows
          .map((row) {
            final c = contacts[row.passengerId];
            if (c == null) return row;
            return DriverManifestRow(
              bookingId: row.bookingId,
              bookingStatus: row.bookingStatus,
              ticketMode: row.ticketMode,
              passengerId: row.passengerId,
              passengerName: row.passengerName,
              passengerPhone: row.passengerPhone ?? c.phone,
              nationalId: row.nationalId ?? c.nationalId,
              seatNumber: row.seatNumber,
              ticketId: row.ticketId,
              ticketType: row.ticketType,
              ticketStatus: row.ticketStatus,
              boardedAt: row.boardedAt,
            );
          })
          .toList();
    } catch (_) {
      return rows;
    }
  }

  Future<void> completeTrip(String tripId) => sb.rpc('complete_trip', params: {'p_trip_id': tripId});

  Future<ScanResult> scan(String token, {String? expectedTripId}) async {
    final params = <String, dynamic>{'p_qr_token': token};
    if (expectedTripId != null) params['p_expected_trip_id'] = expectedTripId;
    final r = await sb.rpc('scan_ticket_qr', params: params);
    return ScanResult.fromMap(Map<String, dynamic>.from(r is List ? r.first : r));
  }
}
