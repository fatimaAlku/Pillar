import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Manama (Bahrain). Used for study-plan calendar days, “today”, and Calendar sync.
const String kAppTimeZoneIana = 'Asia/Bahrain';

bool _timeZonesLoaded = false;

void ensureAppTimeZonesLoaded() {
  if (_timeZonesLoaded) return;
  tz_data.initializeTimeZones();
  _timeZonesLoaded = true;
}

tz.Location get appTimeZoneLocation {
  ensureAppTimeZonesLoaded();
  return tz.getLocation(kAppTimeZoneIana);
}

tz.TZDateTime appNow() => tz.TZDateTime.now(appTimeZoneLocation);

String appTodayDateIso() {
  final n = appNow();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

/// Calendar “today” in [kAppTimeZoneIana], as a date-only local [DateTime] for UI.
DateTime appTodayDateOnly() {
  final n = appNow();
  return DateTime(n.year, n.month, n.day);
}

int appWallClockMinuteOfDay() {
  final n = appNow();
  return n.hour * 60 + n.minute;
}

/// Same instant as [appNow], for APIs that take a [DateTime].
DateTime appNowInstant() => DateTime.fromMillisecondsSinceEpoch(
      appNow().millisecondsSinceEpoch,
      isUtc: true,
    );

/// Parses a calendar day from values like Firestore `yyyy-MM-dd` or ISO strings.
///
/// Leading `yyyy-MM-dd` is read without applying UTC midnight semantics to the
/// whole string, so times attached after `T` do not shift the calendar day.
DateTime? appParseCalendarDateOnly(String value) {
  final trimmed = value.trim();
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
  if (m != null) {
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Inclusive end date for queries: app “today” (Bahrain) + [calendarDays].
///
/// Uses Bahrain midnight stepping so horizon windows stay aligned with session
/// `date` strings regardless of device DST.
String appEndDateIsoFromToday(int calendarDaysFromToday) {
  final n = appNow();
  var t = tz.TZDateTime(appTimeZoneLocation, n.year, n.month, n.day);
  if (calendarDaysFromToday != 0) {
    t = t.add(Duration(days: calendarDaysFromToday));
  }
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}
