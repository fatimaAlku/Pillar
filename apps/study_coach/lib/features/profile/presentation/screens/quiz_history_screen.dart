import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../../quizzes/domain/entities/quiz_history_entry.dart';

class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final uid = authUser?.uid.trim();
    final safeUid = (uid == null || uid.isEmpty) ? null : uid;

    return Scaffold(
      appBar: AppBar(title: Text(strings.history)),
      body: safeUid == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  strings.signInToManageCourses,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ref.watch(quizHistoryStreamProvider(safeUid)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      strings.couldNotLoadHistory,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          strings.noQuizHistory,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _HistoryCard(uid: safeUid, entry: entry);
                    },
                  );
                },
              ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.uid, required this.entry});

  final String uid;
  final QuizHistoryEntry entry;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteQuizHistoryTitle),
        content: Text(strings.deleteQuizHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deleteSessionAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(quizHistoryRepositoryProvider).deleteAttempt(
            uid: uid,
            entryId: entry.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.quizHistoryEntryDeleted)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotDeleteQuizHistoryEntry)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (entry.scoreFraction * 100).round();
    final courseLine = _courseLabelForHistory(entry);
    final showCourseLink =
        courseLine.isNotEmpty || entry.linkedTopicTitles.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _formatDate(entry.completedAt),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context, ref),
                  tooltip: strings.deleteQuizHistoryTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${strings.score}: ${entry.correctCount}/${entry.totalCount} ($percent%)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (showCourseLink) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (courseLine.isNotEmpty)
                          Text(
                            '${strings.quizHistoryCourseLink}: $courseLine',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        if (entry.linkedTopicTitles.isNotEmpty) ...[
                          if (courseLine.isNotEmpty) const SizedBox(height: 4),
                          Text(
                            '${strings.quizHistoryTopicsLink}: ${entry.linkedTopicTitles.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (entry.weakTopicTitles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${strings.weakTopics}: ${entry.weakTopicTitles.join(', ')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }
}

String _courseLabelForHistory(QuizHistoryEntry entry) {
  final title = entry.linkedSubjectTitle?.trim() ?? '';
  if (title.isNotEmpty) return title;
  final id = entry.linkedSubjectId?.trim() ?? '';
  return id.isNotEmpty ? id : '';
}
