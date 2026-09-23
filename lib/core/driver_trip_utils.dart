import '../data/models.dart';
import 'datetime_utils.dart';

const _activeGraceAfterArrival = Duration(hours: 3);

/// Active trips stay in the DB until `complete_trip` runs; ignore stale ones.
bool isDriverTripRelevant(Trip trip) {
  if (trip.status != 'active') return true;
  return !trip.arrival.add(_activeGraceAfterArrival).isBefore(syriaNow());
}

bool isDriverTripUpcoming(Trip trip) {
  if (trip.status == 'active') return isDriverTripRelevant(trip);
  return !trip.departure.isBefore(syriaNow());
}

/// Trip context for QR scan: prefer the trip screen the driver opened.
Trip? resolveDriverScanContextTrip(
  Object? routeExtra, {
  Trip? activeTrip,
  Iterable<Trip> upcoming = const [],
}) {
  if (routeExtra is Trip) return routeExtra;
  if (activeTrip != null) return activeTrip;
  final sorted = upcoming.toList()..sort((a, b) => a.departure.compareTo(b.departure));
  return sorted.isEmpty ? null : sorted.first;
}

/// Picks the trip the driver should treat as "current" (scan / manifest).
Trip? pickDriverCurrentTrip(Iterable<Trip> trips) {
  final now = syriaNow();
  final active = trips.where((t) => t.status == 'active' && isDriverTripRelevant(t)).toList();
  if (active.isEmpty) return null;

  active.sort((a, b) {
    final aInProgress = !a.departure.isAfter(now) && !a.arrival.isBefore(now);
    final bInProgress = !b.departure.isAfter(now) && !b.arrival.isBefore(now);
    if (aInProgress != bInProgress) return aInProgress ? -1 : 1;

    final aStarted = !a.departure.isAfter(now);
    final bStarted = !b.departure.isAfter(now);
    if (aStarted != bStarted) return aStarted ? -1 : 1;

    final aDiff = a.departure.difference(now).abs();
    final bDiff = b.departure.difference(now).abs();
    return aDiff.compareTo(bDiff);
  });
  return active.first;
}
