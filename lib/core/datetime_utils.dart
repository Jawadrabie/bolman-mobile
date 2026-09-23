/// Supabase stores `timestamptz` in UTC. Trip schedules are shown in Syria local
/// time (Asia/Damascus, UTC+3) to match the company dashboard.
const _syriaOffset = Duration(hours: 3);

DateTime utcToSyriaWallClock(DateTime utc) {
  final normalized = utc.isUtc ? utc : utc.toUtc();
  return DateTime(
    normalized.year,
    normalized.month,
    normalized.day,
    normalized.hour,
    normalized.minute,
    normalized.second,
    normalized.millisecond,
    normalized.microsecond,
  ).add(_syriaOffset);
}

/// Syria wall-clock "now" (matches [parseApiDateTime] trip schedules).
DateTime syriaNow() => utcToSyriaWallClock(DateTime.now().toUtc());

/// Start of today in Syria wall-clock time.
DateTime syriaToday() {
  final now = syriaNow();
  return DateTime(now.year, now.month, now.day);
}

/// Parses API timestamps and returns Syria wall-clock [DateTime] (isUtc: false).
DateTime parseApiDateTime(dynamic value) {
  if (value is DateTime) {
    return utcToSyriaWallClock(value.isUtc ? value : value.toUtc());
  }

  final raw = value.toString().trim();
  final hasTimezone = RegExp(r'[zZ]|(?:[+-]\d{2}(?::\d{2})?)$').hasMatch(raw);
  final utc = hasTimezone ? DateTime.parse(raw).toUtc() : DateTime.parse('${raw}Z');
  return utcToSyriaWallClock(utc);
}
