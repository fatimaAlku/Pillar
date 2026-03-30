import 'study_plan.dart';

abstract class PlansRepository {
  Future<StudyPlan> generateStudyPlan({
    required String userId,
    required List<String> subjectIds,
  });
}
