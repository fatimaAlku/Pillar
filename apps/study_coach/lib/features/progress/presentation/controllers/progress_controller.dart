import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../domain/entities/progress_snapshot.dart';
import '../../domain/repositories/progress_repository.dart';

final progressSnapshotProvider = StreamProvider<ProgressSnapshot?>((ref) {
  final user = ref.watch(currentAuthUserProvider).valueOrNull;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(progressRepositoryProvider).watchProgress(user.uid);
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ref.watch(progressRepositoryImplProvider);
});
