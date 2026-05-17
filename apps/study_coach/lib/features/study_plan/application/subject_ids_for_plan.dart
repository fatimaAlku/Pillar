import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_providers.dart';

/// Subject document ids used when refreshing or generating a cloud study plan.
List<String> subjectIdsForStudyPlan(
  WidgetRef ref,
  String uid, {
  String? includeId,
  String? excludeId,
}) {
  final ids = (ref.read(subjectsStreamProvider(uid)).valueOrNull ?? [])
      .map((s) => s.id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (includeId != null && includeId.trim().isNotEmpty) {
    ids.add(includeId.trim());
  }
  if (excludeId != null && excludeId.trim().isNotEmpty) {
    ids.remove(excludeId.trim());
  }
  return ids.toList(growable: false);
}
