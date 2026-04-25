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
                      return _HistoryCard(entry: entry);
                    },
                  );
                },
              ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final QuizHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final percent = (entry.scoreFraction * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(entry.completedAt),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${strings.score}: ${entry.correctCount}/${entry.totalCount} ($percent%)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
