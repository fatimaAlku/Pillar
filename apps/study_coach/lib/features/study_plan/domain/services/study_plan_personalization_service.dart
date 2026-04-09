import '../entities/study_personalization_models.dart';

class StudyPlanPersonalizationService {
  const StudyPlanPersonalizationService();

  /// Priority = deadline urgency + weakness + difficulty + time since last studied
  ///
  /// Returns study tasks sorted by descending priority.
  List<StudyTaskPriority> buildPrioritizedTasks(
    StudyPlanPersonalizationInput input,
  ) {
    return buildDynamicPlan(input).updatedPlan;
  }

  StudyPlanAdjustmentResult buildDynamicPlan(
    StudyPlanPersonalizationInput input,
  ) {
    if (input.topics.isEmpty || input.availableStudyMinutes <= 0) {
      return const StudyPlanAdjustmentResult(
        updatedPlan: [],
        explanationMessage: 'No updates were needed for today\'s plan.',
      );
    }

    final soonSubjects = input.topics
        .where(
          (topic) => _daysUntilExam(now: input.now, exam: topic.examDate) <=
              input.examSoonWindowDays,
        )
        .map((topic) => topic.subjectId)
        .toSet();

    final withScores = input.topics.map((topic) {
      final deadlineUrgency = _deadlineUrgency(now: input.now, exam: topic.examDate);
      final weakness = _clamp01(1 - topic.quizAccuracy);
      final difficulty = _clamp01(topic.subjectDifficulty);
      final timeSinceLastStudied =
          _timeSinceLastStudied(now: input.now, lastStudied: topic.lastStudiedAt);
      final lowQuizBoost = _lowQuizBoost(
        quizAccuracy: topic.quizAccuracy,
        threshold: input.quizLowThreshold,
      );
      final examSoonBoost = _examSoonBoost(
        now: input.now,
        examDate: topic.examDate,
        soonWindowDays: input.examSoonWindowDays,
      );
      final subjectSoonBoost = soonSubjects.contains(topic.subjectId) ? 0.25 : 0.0;
      final missedSessionsBoost = _missedSessionsBoost(topic.missedSessions);

      final score = deadlineUrgency +
          weakness +
          difficulty +
          timeSinceLastStudied +
          lowQuizBoost +
          examSoonBoost +
          subjectSoonBoost +
          missedSessionsBoost;
      return _ScoredTopic(
        source: topic,
        score: score,
        deadlineUrgency: deadlineUrgency,
        weakness: weakness,
        difficulty: difficulty,
        timeSinceLastStudied: timeSinceLastStudied,
        lowQuizBoost: lowQuizBoost,
        examSoonBoost: examSoonBoost + subjectSoonBoost,
        missedSessionsBoost: missedSessionsBoost,
        reason: _reasonForTopic(
          topic: topic,
          now: input.now,
          quizLowThreshold: input.quizLowThreshold,
          examSoonWindowDays: input.examSoonWindowDays,
        ),
      );
    }).toList();

    withScores.sort((a, b) => b.score.compareTo(a.score));
    final minutesByTopic = _allocateMinutes(
      sortedByPriority: withScores,
      totalMinutes: input.availableStudyMinutes,
    );
    final redistributedMinutes = _redistributeForMissedSessions(
      sortedByPriority: withScores,
      allocated: minutesByTopic,
    );

    final updatedPlan = withScores
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
            recommendedMinutes: redistributedMinutes[item.source.topicId] ?? 0,
            adjustmentReason: item.reason,
          ),
        )
        .toList(growable: false);

    final explanation = _buildExplanationMessage(updatedPlan);
    return StudyPlanAdjustmentResult(
      updatedPlan: updatedPlan,
      explanationMessage: explanation,
    );
  }

  double _deadlineUrgency({required DateTime now, required DateTime exam}) {
    final daysUntilExam = _daysUntilExam(now: now, exam: exam);
    if (daysUntilExam <= 0) return 1.0;
    // Decays over a 30-day window: closer exam => higher urgency.
    return _clamp01((30 - daysUntilExam) / 30);
  }

  double _daysUntilExam({required DateTime now, required DateTime exam}) {
    return exam.difference(now).inHours / 24;
  }

  double _lowQuizBoost({
    required double quizAccuracy,
    required double threshold,
  }) {
    if (quizAccuracy >= threshold) return 0;
    final span = threshold <= 0 ? 1.0 : threshold;
    return _clamp01((threshold - quizAccuracy) / span) * 0.9;
  }

  double _examSoonBoost({
    required DateTime now,
    required DateTime examDate,
    required int soonWindowDays,
  }) {
    if (soonWindowDays <= 0) return 0;
    final daysUntilExam = _daysUntilExam(now: now, exam: examDate);
    if (daysUntilExam > soonWindowDays) return 0;
    if (daysUntilExam <= 0) return 0.9;
    return _clamp01((soonWindowDays - daysUntilExam) / soonWindowDays) * 0.9;
  }

  double _missedSessionsBoost(int missedSessions) {
    if (missedSessions <= 0) return 0;
    return _clamp01(missedSessions / 3) * 0.8;
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

  Map<String, int> _redistributeForMissedSessions({
    required List<_ScoredTopic> sortedByPriority,
    required Map<String, int> allocated,
  }) {
    if (sortedByPriority.isEmpty) return allocated;
    final result = Map<String, int>.from(allocated);
    final missedTopics = sortedByPriority
        .where((topic) => topic.source.missedSessions > 0)
        .toList(growable: false);
    if (missedTopics.isEmpty) return result;

    for (final missed in missedTopics) {
      var bonus = missed.source.missedSessions * 5;
      while (bonus > 0) {
        final donor = sortedByPriority.lastWhere(
          (topic) =>
              topic.source.topicId != missed.source.topicId &&
              (result[topic.source.topicId] ?? 0) > 10,
          orElse: () => missed,
        );
        if (donor.source.topicId == missed.source.topicId) break;
        result[donor.source.topicId] = (result[donor.source.topicId] ?? 0) - 1;
        result[missed.source.topicId] = (result[missed.source.topicId] ?? 0) + 1;
        bonus -= 1;
      }
    }

    return result;
  }

  String _reasonForTopic({
    required TopicPerformanceInput topic,
    required DateTime now,
    required double quizLowThreshold,
    required int examSoonWindowDays,
  }) {
    if (topic.quizAccuracy < quizLowThreshold) {
      return 'low quiz performance';
    }

    final daysUntilExam = _daysUntilExam(now: now, exam: topic.examDate);
    if (daysUntilExam <= examSoonWindowDays) {
      return 'upcoming exam';
    }

    if (topic.missedSessions > 0) {
      return 'missed sessions';
    }

    return 'baseline personalization';
  }

  String _buildExplanationMessage(List<StudyTaskPriority> plan) {
    if (plan.isEmpty) return 'No updates were needed for today\'s plan.';
    final top = plan.first;
    final reason = top.adjustmentReason ?? 'personalized signals';
    return '${top.topicTitle} was scheduled earlier due to $reason.';
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
    required this.lowQuizBoost,
    required this.examSoonBoost,
    required this.missedSessionsBoost,
    required this.reason,
  });

  final TopicPerformanceInput source;
  final double score;
  final double deadlineUrgency;
  final double weakness;
  final double difficulty;
  final double timeSinceLastStudied;
  final double lowQuizBoost;
  final double examSoonBoost;
  final double missedSessionsBoost;
  final String reason;
}

