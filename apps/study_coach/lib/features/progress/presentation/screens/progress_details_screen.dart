import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../roadmap/domain/major_catalog.dart';
import '../controllers/progress_controller.dart';

class ProgressDetailsScreen extends ConsumerWidget {
  const ProgressDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final progressAsync = ref.watch(progressSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.progressOverview)),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 34,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  strings.progressLoadFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(progressSnapshotProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
        data: (snapshot) {
          if (snapshot == null) {
            return Center(child: Text(strings.login));
          }
          final overallPercent = (snapshot.overallProgress * 100).round();
          final roadmapPercent = (snapshot.roadmapCompletion * 100).round();
          final sessionsPercent = (snapshot.sessionsCompletion * 100).round();
          final quizPercent = (snapshot.avgScore * 100).round();
          final majorTitle = majorTitleFromId(snapshot.majorId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (majorTitle.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(strings.yourMajor(majorTitle)),
                  ),
                ),
              const SizedBox(height: 10),
              _MetricCard(
                title: strings.overallProgress,
                percent: overallPercent,
                value: snapshot.overallProgress,
              ),
              const SizedBox(height: 10),
              _MetricCard(
                title: strings.roadmapProgress,
                percent: roadmapPercent,
                value: snapshot.roadmapCompletion,
              ),
              const SizedBox(height: 10),
              _MetricCard(
                title: strings.sessionsProgress,
                percent: sessionsPercent,
                value: snapshot.sessionsCompletion,
              ),
              const SizedBox(height: 10),
              _MetricCard(
                title: strings.quizAverage,
                percent: quizPercent,
                value: snapshot.avgScore,
              ),
              const SizedBox(height: 16),
              Text(
                strings.weakTopics,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (snapshot.weakAreas.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(strings.noWeakAreasYet),
                  ),
                )
              else
                ...snapshot.weakAreas.map(
                  (area) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.trending_down_rounded),
                      title: Text(area),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.percent,
    required this.value,
  });

  final String title;
  final int percent;
  final double value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text('$percent%'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 10,
                color: colorScheme.primary,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
