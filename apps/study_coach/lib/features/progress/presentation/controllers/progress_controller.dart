import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/feature_state.dart';

final progressControllerProvider = Provider<FeatureState>((ref) {
  return const FeatureState('insights_collection_ready');
});
