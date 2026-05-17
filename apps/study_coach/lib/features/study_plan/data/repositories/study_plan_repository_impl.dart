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

  @override
  Future<void> refreshOrGenerateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  }) async {
    final uniq = subjectIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniq.isEmpty) return;

    final rebalance =
        await _functions.httpsCallable('rebalanceStudyPlan').call();
    final data = rebalance.data;
    if (data is Map) {
      if (data['updated'] == true) return;
      final reason = data['reason'];
      if (reason == 'no_active_plan' || reason == 'no_subjects_on_plan') {
        await generateStudyPlan(uid: uid, subjectIds: uniq);
      }
    }
  }
}
