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
