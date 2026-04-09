import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/feature_state.dart';
import '../../domain/entities/study_personalization_models.dart';
import '../../domain/services/study_plan_personalization_service.dart';

final studyPlanControllerProvider = Provider<FeatureState>((ref) {
  return const FeatureState('cloud_function_ready:generateStudyPlan/rebalance');
});

final studyPlanPersonalizationServiceProvider =
    Provider<StudyPlanPersonalizationService>((ref) {
  return const StudyPlanPersonalizationService();
});

final studyPlanPrioritizedTasksProvider = Provider.family<
    List<StudyTaskPriority>,
    StudyPlanPersonalizationInput>((ref, input) {
  final result = ref.watch(studyPlanDynamicResultProvider(input));
  return result.updatedPlan;
});

final studyPlanDynamicResultProvider = Provider.family<
    StudyPlanAdjustmentResult,
    StudyPlanPersonalizationInput>((ref, input) {
  final service = ref.watch(studyPlanPersonalizationServiceProvider);
  return service.buildDynamicPlan(input);
});
