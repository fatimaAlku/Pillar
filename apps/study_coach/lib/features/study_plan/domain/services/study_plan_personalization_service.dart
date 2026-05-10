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
      totalMinutes: input.availableStudyMinutes,
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

  /// Distributes [totalMinutes] across [sortedByPriority] proportionally to
  /// their scores. Topics that would otherwise receive less than the minimum
  /// session length are dropped so the user sees fewer, focused suggestions
  /// instead of unusable 1-minute slivers.
  Map<String, int> _allocateMinutes({
    required List<_ScoredTopic> sortedByPriority,
    required int totalMinutes,
  }) {
    if (sortedByPriority.isEmpty || totalMinutes <= 0) return const {};

    final minSession = _minSessionMinutes(totalMinutes);
    final maxTopics = (totalMinutes ~/ minSession).clamp(1, sortedByPriority.length);
    final selected = sortedByPriority.take(maxTopics).toList(growable: false);

    final result = <String, int>{
      for (final t in sortedByPriority) t.source.topicId: 0,
    };

    final sum = selected.fold<double>(0, (acc, t) => acc + t.score);
    if (sum <= 0) {
      final even = totalMinutes ~/ selected.length;
      for (final t in selected) {
        result[t.source.topicId] = even;
      }
      var leftover = totalMinutes - (even * selected.length);
      for (final t in selected) {
        if (leftover <= 0) break;
        result[t.source.topicId] = (result[t.source.topicId] ?? 0) + 1;
        leftover -= 1;
      }
      return result;
    }

    var remaining = totalMinutes;
    // First pass: give each selected topic at least the minimum session.
    for (final t in selected) {
      result[t.source.topicId] = minSession;
      remaining -= minSession;
    }
    if (remaining < 0) {
      // Budget can't support all selected at the minimum; trim from the lowest priority.
      var deficit = -remaining;
      for (final t in selected.reversed) {
        if (deficit <= 0) break;
        final current = result[t.source.topicId] ?? 0;
        if (current <= 0) continue;
        final take = current >= deficit ? deficit : current;
        result[t.source.topicId] = current - take;
        deficit -= take;
      }
      return result;
    }

    if (remaining == 0) return result;

    // Second pass: distribute leftover proportionally to score weight.
    for (final t in selected) {
      final share = (t.score / sum) * remaining;
      final extra = share.floor();
      result[t.source.topicId] = (result[t.source.topicId] ?? 0) + extra;
    }
    var used =
        result.values.fold<int>(0, (acc, value) => acc + value);
    var leftover = totalMinutes - used;
    var i = 0;
    while (leftover > 0 && selected.isNotEmpty) {
      final topic = selected[i % selected.length];
      result[topic.source.topicId] = (result[topic.source.topicId] ?? 0) + 1;
      leftover -= 1;
      i += 1;
    }

    return result;
  }

  /// Shifts a budget-aware bonus from low-priority donors toward topics with
  /// missed sessions so the user sees real catch-up time on tomorrow's plan.
  Map<String, int> _redistributeForMissedSessions({
    required List<_ScoredTopic> sortedByPriority,
    required Map<String, int> allocated,
    required int totalMinutes,
  }) {
    if (sortedByPriority.isEmpty) return allocated;
    final result = Map<String, int>.from(allocated);
    final missedTopics = sortedByPriority
        .where((topic) => topic.source.missedSessions > 0)
        .toList(growable: false);
    if (missedTopics.isEmpty) return result;

    final minSession = _minSessionMinutes(totalMinutes);
    final donorFloor = (minSession * 1.5).round();
    final perMissedBonus = (totalMinutes / 12).clamp(5, 25).round();

    for (final missed in missedTopics) {
      var bonus = (missed.source.missedSessions * perMissedBonus)
          .clamp(0, totalMinutes ~/ 2);
      while (bonus > 0) {
        _ScoredTopic? donor;
        for (final candidate in sortedByPriority.reversed) {
          if (candidate.source.topicId == missed.source.topicId) continue;
          if ((result[candidate.source.topicId] ?? 0) > donorFloor) {
            donor = candidate;
            break;
          }
        }
        if (donor == null) break;
        result[donor.source.topicId] = (result[donor.source.topicId] ?? 0) - 1;
        result[missed.source.topicId] = (result[missed.source.topicId] ?? 0) + 1;
        bonus -= 1;
      }
    }

    return result;
  }

  /// Picks a minimum useful session length that scales with the day's budget
  /// so very small budgets still produce at least one substantive block.
  int _minSessionMinutes(int totalMinutes) {
    if (totalMinutes <= 30) return totalMinutes;
    if (totalMinutes <= 60) return 20;
    return 25;
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

    final lastStudied = topic.lastStudiedAt;
    if (lastStudied == null ||
        now.difference(lastStudied).inDays >= 7) {
      return 'long time since last study';
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

