import 'dart:async';

import '../../recommendations/domain/repositories/recommendations_repository.dart';
import '../domain/repositories/study_plan_repository.dart';

/// Fire-and-forget refresh of insights + cloud rebalance without blocking UI.
void scheduleStudyPlanRebalance(
  StudyPlanRepository repository, {
  RecommendationsRepository? recommendationsRepository,
}) {
  unawaited(_refreshInsightsAndRebalanceQuietly(
    repository,
    recommendationsRepository,
  ));
}

Future<void> _refreshInsightsAndRebalanceQuietly(
  StudyPlanRepository repository,
  RecommendationsRepository? recommendationsRepository,
) async {
  try {
    await recommendationsRepository?.generateRecommendations();
  } catch (_) {}
  try {
    await repository.rebalanceStudyPlan();
  } catch (_) {}
}
