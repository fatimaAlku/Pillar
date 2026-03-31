import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/state/feature_state.dart';

final authControllerProvider = Provider<FeatureState>((ref) {
  final userAsync = ref.watch(currentAuthUserProvider);
  final user = userAsync.valueOrNull;
  final status = user == null ? 'signed_out_or_loading' : 'signed_in';
  return FeatureState(status);
});
