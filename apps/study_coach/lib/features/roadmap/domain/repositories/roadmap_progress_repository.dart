abstract class RoadmapProgressRepository {
  Stream<Set<String>> watchCompletedItemKeys({
    required String uid,
    required String majorId,
  });

  Future<void> toggleItem({
    required String uid,
    required String majorId,
    required String itemKey,
    required bool completed,
    required int totalItemCount,
  });
}
