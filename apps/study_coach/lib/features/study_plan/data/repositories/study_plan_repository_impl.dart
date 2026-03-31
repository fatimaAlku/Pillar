import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/repositories/study_plan_repository.dart';

class StudyPlanRepositoryImpl implements StudyPlanRepository {
  StudyPlanRepositoryImpl(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> generateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  }) async {
    await _functions.httpsCallable('generateStudyPlan').call(<String, dynamic>{
      'subjectIds': subjectIds,
      'uid': uid,
    });
  }

  @override
  Future<void> rebalanceStudyPlan() async {
    await _functions.httpsCallable('rebalanceStudyPlan').call();
  }
}
