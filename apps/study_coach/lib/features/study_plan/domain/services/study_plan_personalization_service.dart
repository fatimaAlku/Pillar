import '../entities/study_personalization_models.dart';

class StudyPlanPersonalizationService {
  const StudyPlanPersonalizationService();

  /// Priority = deadline urgency + weakness + difficulty + time since last studied
  ///
  /// Returns study tasks sorted by descending priority.
  List<StudyTaskPriority> buildPrioritizedTasks(
    StudyPlanPersonalizationInput input,
  ) {
    if (input.topics.isEmpty) return const [];
    if (input.availableStudyMinutes <= 0) return const [];

    final withScores = input.topics.map((topic) {
      final deadlineUrgency = _deadlineUrgency(now: input.now, exam: topic.examDate);
      final weakness = _clamp01(1 - topic.quizAccuracy);
      final difficulty = _clamp01(topic.subjectDifficulty);
      final timeSinceLastStudied =
          _timeSinceLastStudied(now: input.now, lastStudied: topic.lastStudiedAt);

      final score = deadlineUrgency + weakness + difficulty + timeSinceLastStudied;
      return _ScoredTopic(
        source: topic,
        score: score,
        deadlineUrgency: deadlineUrgency,
        weakness: weakness,
        difficulty: difficulty,
        timeSinceLastStudied: timeSinceLastStudied,
      );
    }).toList();

    withScores.sort((a, b) => b.score.compareTo(a.score));
    final minutesByTopic = _allocateMinutes(
      sortedByPriority: withScores,
      totalMinutes: input.availableStudyMinutes,
    );

    return withScores
        .map(
          (item) => StudyTaskPriority(
            topicId: item.source.topicId,
            topicTitle: item.source.topicTitle,
            subjectId: item.source.subjectId,
            subjectTitle: item.source.subjectTitle,
            priorityScore: item.score,
            deadlineUrgency: item.deadlineUrgency,
            weakness: item.weakness,
            difficulty: item.difficulty,
            timeSinceLastStudied: item.timeSinceLastStudied,
            recommendedMinutes: minutesByTopic[item.source.topicId] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  double _deadlineUrgency({required DateTime now, required DateTime exam}) {
    final daysUntilExam = exam.difference(now).inHours / 24;
    if (daysUntilExam <= 0) return 1.0;
    // Decays over a 30-day window: closer exam => higher urgency.
    return _clamp01((30 - daysUntilExam) / 30);
  }

  double _timeSinceLastStudied({
    required DateTime now,
    required DateTime? lastStudied,
  }) {
    if (lastStudied == null) return 1.0;
    final days = now.difference(lastStudied).inHours / 24;
    if (days <= 0) return 0;
    // Saturates at 14 days.
    return _clamp01(days / 14);
  }

  Map<String, int> _allocateMinutes({
    required List<_ScoredTopic> sortedByPriority,
    required int totalMinutes,
  }) {
    if (sortedByPriority.isEmpty || totalMinutes <= 0) return const {};

    final sum = sortedByPriority.fold<double>(0, (acc, t) => acc + t.score);
    if (sum <= 0) {
      final even = totalMinutes ~/ sortedByPriority.length;
      final map = <String, int>{
        for (final t in sortedByPriority) t.source.topicId: even,
      };
      var leftover = totalMinutes - (even * sortedByPriority.length);
      for (final t in sortedByPriority) {
        if (leftover <= 0) break;
        map[t.source.topicId] = (map[t.source.topicId] ?? 0) + 1;
        leftover -= 1;
      }
      return map;
    }

    final allocation = <String, int>{};
    var used = 0;
    for (final t in sortedByPriority) {
      final share = (t.score / sum) * totalMinutes;
      final minutes = share.floor();
      allocation[t.source.topicId] = minutes;
      used += minutes;
    }

    var remaining = totalMinutes - used;
    var i = 0;
    while (remaining > 0) {
      final topic = sortedByPriority[i % sortedByPriority.length];
      allocation[topic.source.topicId] = (allocation[topic.source.topicId] ?? 0) + 1;
      remaining -= 1;
      i += 1;
    }

    return allocation;
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

class _ScoredTopic {
  const _ScoredTopic({
    required this.source,
    required this.score,
    required this.deadlineUrgency,
    required this.weakness,
    required this.difficulty,
    required this.timeSinceLastStudied,
  });

  final TopicPerformanceInput source;
  final double score;
  final double deadlineUrgency;
  final double weakness;
  final double difficulty;
  final double timeSinceLastStudied;
}

