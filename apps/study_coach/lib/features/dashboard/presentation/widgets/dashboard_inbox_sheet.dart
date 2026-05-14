import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_time_zone.dart';
import '../../../../core/localization/app_strings.dart';
import '../providers/dashboard_inbox_provider.dart';

String _sessionSubtitle(
  BuildContext context,
  AppStrings strings,
  DashboardInboxEntry entry,
) {
  final s = entry.session;
  if (s == null) return '';
  final d = appParseCalendarDateOnly(s.date);
  final locale = Localizations.localeOf(context).toString();
  final dateStr = d == null ? s.date : DateFormat.yMMMd(locale).format(d);
  final sm = s.startMinute;
  if (sm != null) {
    final t = TimeOfDay(hour: sm ~/ 60, minute: sm % 60);
    final timeStr = t.format(context);
    final topic = (entry.topicTitle ?? '').trim().isEmpty
        ? strings.inboxStudyTopicFallback
        : entry.topicTitle!.trim();
    return strings.inboxUpcomingSessionBody('$dateStr · $timeStr', topic);
  }
  final topic = (entry.topicTitle ?? '').trim().isEmpty
      ? strings.inboxStudyTopicFallback
      : entry.topicTitle!.trim();
  return strings.inboxUpcomingSessionBody(dateStr, topic);
}

class DashboardInboxSheet extends ConsumerWidget {
  const DashboardInboxSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entries = ref.watch(dashboardInboxEntriesProvider);

    final headerStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final itemTitleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final itemBodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    final actionTextStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.inboxTitle,
              style: headerStyle,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  strings.inboxEmpty,
                  textAlign: TextAlign.center,
                  style: itemBodyStyle?.copyWith(fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    switch (e.kind) {
                      case DashboardInboxKind.emailVerified:
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                colorScheme.primaryContainer.withValues(
                              alpha: 0.7,
                            ),
                            child: Icon(
                              Icons.mark_email_read_outlined,
                              size: 20,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            strings.inboxEmailVerifiedTitle,
                            style: itemTitleStyle,
                          ),
                          subtitle: Text(
                            strings.inboxEmailVerifiedBody,
                            style: itemBodyStyle,
                          ),
                          trailing: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: actionTextStyle,
                            ),
                            onPressed: () async {
                              await dismissInboxEmailVerifiedNotification(ref);
                            },
                            child: Text(strings.inboxDismiss),
                          ),
                        );
                      case DashboardInboxKind.upcomingSession:
                        final session = e.session!;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                colorScheme.secondaryContainer.withValues(
                              alpha: 0.85,
                            ),
                            child: Icon(
                              Icons.event_note_outlined,
                              size: 20,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          title: Text(
                            strings.inboxUpcomingSessionTitle,
                            style: itemTitleStyle,
                          ),
                          subtitle: Text(
                            _sessionSubtitle(context, strings, e),
                            style: itemBodyStyle,
                          ),
                          trailing: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: actionTextStyle,
                            ),
                            onPressed: () async {
                              await dismissInboxUpcomingSession(ref, session);
                            },
                            child: Text(strings.inboxDismiss),
                          ),
                        );
                      case DashboardInboxKind.syncGoogleCalendar:
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                colorScheme.tertiaryContainer.withValues(
                              alpha: 0.85,
                            ),
                            child: Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                          title: Text(
                            strings.inboxSyncGoogleTitle,
                            style: itemTitleStyle,
                          ),
                          subtitle: Text(
                            strings.inboxSyncGoogleBody,
                            style: itemBodyStyle,
                          ),
                          trailing: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: actionTextStyle,
                            ),
                            onPressed: () async {
                              await dismissInboxGoogleSyncReminder(ref);
                            },
                            child: Text(strings.inboxDismiss),
                          ),
                        );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
