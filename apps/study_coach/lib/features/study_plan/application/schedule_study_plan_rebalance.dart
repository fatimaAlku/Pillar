import 'dart:async';

import '../domain/repositories/study_plan_repository.dart';

/// Fire-and-forget cloud rebalance (exams, quiz signals, topic list) without blocking UI.
void scheduleStudyPlanRebalance(StudyPlanRepository repository) {
  unawaited(_rebalanceQuietly(repository));
}

Future<void> _rebalanceQuietly(StudyPlanRepository repository) async {
  try {
    await repository.rebalanceStudyPlan();
  } catch (_) {}
}
