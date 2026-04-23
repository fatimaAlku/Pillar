import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../data/repositories/roadmap_progress_repository_impl.dart';
import '../../domain/repositories/roadmap_progress_repository.dart';

final roadmapProgressRepositoryProvider = Provider<RoadmapProgressRepository>(
  (ref) => RoadmapProgressRepositoryImpl(ref.watch(firestoreProvider)),
);

class RoadmapProgressKey {
  const RoadmapProgressKey({
    required this.uid,
    required this.majorId,
  });

  final String uid;
  final String majorId;

  @override
  bool operator ==(Object other) =>
      other is RoadmapProgressKey &&
      other.uid == uid &&
      other.majorId == majorId;

  @override
  int get hashCode => Object.hash(uid, majorId);
}

final roadmapCompletedItemsStreamProvider =
    StreamProvider.autoDispose.family<Set<String>, RoadmapProgressKey>(
  (ref, key) {
    return ref.watch(roadmapProgressRepositoryProvider).watchCompletedItemKeys(
          uid: key.uid,
          majorId: key.majorId,
        );
  },
);
