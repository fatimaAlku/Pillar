import 'dart:async';

import '../../recommendations/domain/repositories/recommendations_repository.dart';
import '../domain/repositories/study_plan_repository.dart';

/// Fire-and-forget refresh of insights + cloud plan refresh without blocking UI.
void scheduleStudyPlanRebalance(
  StudyPlanRepository repository, {
  RecommendationsRepository? recommendationsRepository,
  required String uid,
  List<String> subjectIds = const [],
}) {
  unawaited(_refreshInsightsAndRebalanceQuietly(
    repository,
    recommendationsRepository,
    uid: uid,
    subjectIds: subjectIds,
  ));
}

Future<void> _refreshInsightsAndRebalanceQuietly(
  StudyPlanRepository repository,
  RecommendationsRepository? recommendationsRepository, {
  required String uid,
  required List<String> subjectIds,
}) async {
  try {
    await recommendationsRepository?.generateRecommendations();
  } catch (_) {}
  try {
    if (subjectIds.isNotEmpty) {
      await repository.refreshOrGenerateStudyPlan(
        uid: uid,
        subjectIds: subjectIds,
      );
    } else {
      await repository.rebalanceStudyPlan();
    }
  } catch (_) {}
}
