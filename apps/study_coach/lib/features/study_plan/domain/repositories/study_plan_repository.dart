abstract class StudyPlanRepository {
  Future<void> generateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  });

  Future<void> rebalanceStudyPlan();
}
