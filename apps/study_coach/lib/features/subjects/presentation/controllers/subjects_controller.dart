import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/state/feature_state.dart';

final subjectsControllerProvider = Provider<FeatureState>((ref) {
  final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
  if (authUser == null) {
    return const FeatureState('needs_auth');
  }

  ref.watch(subjectsStreamProvider(authUser.uid));
  return const FeatureState('watching_firestore_subjects');
});
