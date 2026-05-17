abstract class StudyPlanRepository {
  Future<void> generateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  });

  Future<void> rebalanceStudyPlan();

  /// Rebalances the active plan, or generates one when none exists yet.
  Future<void> refreshOrGenerateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  });
}
