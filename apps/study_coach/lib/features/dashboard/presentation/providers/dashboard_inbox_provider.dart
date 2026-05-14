import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/config/app_time_zone.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/state/google_calendar_connection_provider.dart';
import '../../../study_plan/domain/entities/study_personalization_models.dart';
import '../../../study_plan/domain/entities/study_session.dart';
import '../../../study_plan/presentation/controllers/study_plan_firestore_providers.dart';

const _kInboxEmailVerifiedDismissed = 'pillar_inbox_email_verified_dismissed';
const _kInboxDismissedUpcomingSession =
    'pillar_inbox_dismissed_upcoming_session';
const _kInboxGoogleSyncDismissed = 'pillar_inbox_google_sync_dismissed';

String inboxUpcomingSessionDismissKey(StudySession s) => '${s.planId}|${s.id}';

enum DashboardInboxKind {
  emailVerified,
  upcomingSession,
  syncGoogleCalendar,
}

class DashboardInboxEntry {
  const DashboardInboxEntry._({
    required this.kind,
    this.session,
    this.topicTitle,
  });

  const DashboardInboxEntry.emailVerified()
      : this._(kind: DashboardInboxKind.emailVerified);

  const DashboardInboxEntry.upcoming({
    required StudySession session,
    required String topicTitle,
  }) : this._(
          kind: DashboardInboxKind.upcomingSession,
          session: session,
          topicTitle: topicTitle,
        );

  const DashboardInboxEntry.googleSync()
      : this._(kind: DashboardInboxKind.syncGoogleCalendar);

  final DashboardInboxKind kind;
  final StudySession? session;
  final String? topicTitle;
}

StudySession? _pickNextUpcomingIncomplete(List<StudySession> sessions) {
  final now = appNow();
  for (final s in sessions) {
    if (s.completed) continue;
    final d = appParseCalendarDateOnly(s.date);
    if (d == null) continue;
    final sm = s.startMinute;
    final tz.TZDateTime start = sm == null
        ? tz.TZDateTime(appTimeZoneLocation, d.year, d.month, d.day, 8, 0)
        : tz.TZDateTime(
            appTimeZoneLocation,
            d.year,
            d.month,
            d.day,
            sm ~/ 60,
            sm % 60,
          );
    final end = start.add(Duration(minutes: s.durationMin));
    if (end.isAfter(now)) return s;
  }
  return null;
}

Future<void> dismissInboxEmailVerifiedNotification(WidgetRef ref) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kInboxEmailVerifiedDismissed, true);
  ref.invalidate(inboxEmailVerifiedDismissedProvider);
}

Future<void> dismissInboxUpcomingSession(
    WidgetRef ref, StudySession session) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(
    _kInboxDismissedUpcomingSession,
    inboxUpcomingSessionDismissKey(session),
  );
  ref.invalidate(inboxDismissedUpcomingSessionKeyProvider);
}

Future<void> dismissInboxGoogleSyncReminder(WidgetRef ref) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kInboxGoogleSyncDismissed, true);
  ref.invalidate(inboxGoogleSyncDismissedProvider);
}

/// Clears the Google sync nudge dismiss flag once Calendar is connected so a
/// later disconnect can show the nudge again.
Future<void> clearInboxGoogleSyncDismissIfConnected(
  WidgetRef ref, {
  required bool connected,
  required bool needsReconnect,
}) async {
  if (!connected || needsReconnect) return;
  final p = await SharedPreferences.getInstance();
  if (p.getBool(_kInboxGoogleSyncDismissed) != true) return;
  await p.remove(_kInboxGoogleSyncDismissed);
  ref.invalidate(inboxGoogleSyncDismissedProvider);
}

final inboxEmailVerifiedDismissedProvider = FutureProvider<bool>((ref) async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(_kInboxEmailVerifiedDismissed) ?? false;
});

final inboxDismissedUpcomingSessionKeyProvider =
    FutureProvider<String?>((ref) async {
  final p = await SharedPreferences.getInstance();
  final v = p.getString(_kInboxDismissedUpcomingSession)?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
});

final inboxGoogleSyncDismissedProvider = FutureProvider<bool>((ref) async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(_kInboxGoogleSyncDismissed) ?? false;
});

final googleCalendarStatusForDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(googleCalendarConnectionBumpProvider);
  final user = ref.watch(currentAuthUserProvider).valueOrNull;
  if (user == null) {
    return {'connected': false, 'needsReconnect': false};
  }
  try {
    return await ref.read(googleCalendarSyncRepositoryProvider).googleStatus();
  } catch (_) {
    return {'connected': false, 'needsReconnect': false};
  }
});

final dashboardInboxEntriesProvider =
    Provider.autoDispose<List<DashboardInboxEntry>>((ref) {
  final uid = ref.watch(currentAuthUserProvider).valueOrNull?.uid;
  if (uid == null) return const [];

  final emailDismissed =
      ref.watch(inboxEmailVerifiedDismissedProvider).valueOrNull ?? false;
  final dismissedUpcomingKey =
      ref.watch(inboxDismissedUpcomingSessionKeyProvider).valueOrNull;
  final googleDismissed =
      ref.watch(inboxGoogleSyncDismissedProvider).valueOrNull ?? false;

  final upcoming = ref.watch(upcomingSessionsStreamProvider(uid)).valueOrNull ??
      const <StudySession>[];

  final topics = ref.watch(enrichedTopicPerformanceInputsProvider(uid));

  final topicById = <String, TopicPerformanceInput>{
    for (final t in topics) t.topicId: t,
  };

  final items = <DashboardInboxEntry>[];

  if (!emailDismissed) {
    items.add(const DashboardInboxEntry.emailVerified());
  }

  final next = _pickNextUpcomingIncomplete(upcoming);
  if (next != null &&
      dismissedUpcomingKey != inboxUpcomingSessionDismissKey(next)) {
    final rawTitle = topicById[next.topicId]?.topicTitle.trim() ?? '';
    final topicTitle = rawTitle.isNotEmpty
        ? rawTitle
        : (next.topicId.trim().isNotEmpty ? next.topicId : '');
    items.add(
      DashboardInboxEntry.upcoming(
        session: next,
        topicTitle: topicTitle,
      ),
    );
  }

  final googleMap =
      ref.watch(googleCalendarStatusForDashboardProvider).valueOrNull;
  if (googleMap != null) {
    final connected = googleMap['connected'] == true;
    final needsReconnect = googleMap['needsReconnect'] == true;
    if ((!connected || needsReconnect) && !googleDismissed) {
      items.add(const DashboardInboxEntry.googleSync());
    }
  }

  return items;
});
