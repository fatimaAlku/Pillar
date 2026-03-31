import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/feature_state.dart';

final studyPlanControllerProvider = Provider<FeatureState>((ref) {
  return const FeatureState('cloud_function_ready:generateStudyPlan/rebalance');
});
