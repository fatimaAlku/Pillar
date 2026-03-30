import 'plans_repository.dart';
import 'study_plan.dart';

class GenerateStudyPlanUseCase {
  const GenerateStudyPlanUseCase(this._plansRepository);

  final PlansRepository _plansRepository;

  Future<StudyPlan> call({
    required String userId,
    required List<String> subjectIds,
  }) {
    return _plansRepository.generateStudyPlan(
      userId: userId,
      subjectIds: subjectIds,
    );
  }
}
