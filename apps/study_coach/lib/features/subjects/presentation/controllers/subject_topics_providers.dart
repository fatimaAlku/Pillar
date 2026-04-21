import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../domain/entities/topic_item.dart';

/// [Riverpod] family key for `watchTopics(uid, subjectId)`.
class SubjectTopicsKey {
  const SubjectTopicsKey(this.uid, this.subjectId);

  final String uid;
  final String subjectId;

  @override
  bool operator ==(Object other) =>
      other is SubjectTopicsKey &&
      other.uid == uid &&
      other.subjectId == subjectId;

  @override
  int get hashCode => Object.hash(uid, subjectId);
}

final subjectTopicsStreamProvider =
    StreamProvider.autoDispose.family<List<TopicItem>, SubjectTopicsKey>(
  (ref, key) {
    return ref.watch(subjectsRepositoryProvider).watchTopics(
          uid: key.uid,
          subjectId: key.subjectId,
        );
  },
);
