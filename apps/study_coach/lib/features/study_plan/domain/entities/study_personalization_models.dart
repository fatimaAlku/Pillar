class TopicPerformanceInput {
  const TopicPerformanceInput({
    required this.topicId,
    required this.topicTitle,
    required this.subjectId,
    required this.subjectTitle,
    required this.examDate,
    required this.quizAccuracy,
    required this.subjectDifficulty,
    this.lastStudiedAt,
    this.missedSessions = 0,
  });

  final String topicId;
  final String topicTitle;
  final String subjectId;
  final String subjectTitle;
  final DateTime examDate;

  /// 0.0 to 1.0 where 1.0 means strongest performance.
  final double quizAccuracy;

  /// 0.0 to 1.0 where 1.0 means most difficult.
  final double subjectDifficulty;

  final DateTime? lastStudiedAt;
  final int missedSessions;
}

class StudyPlanPersonalizationInput {
  const StudyPlanPersonalizationInput({
    required this.topics,
    required this.availableStudyMinutes,
    required this.now,
    this.quizLowThreshold = 0.6,
    this.examSoonWindowDays = 7,
  });

  final List<TopicPerformanceInput> topics;
  final int availableStudyMinutes;
  final DateTime now;
  final double quizLowThreshold;
  final int examSoonWindowDays;
}

class StudyTaskPriority {
  const StudyTaskPriority({
    required this.topicId,
    required this.topicTitle,
    required this.subjectId,
    required this.subjectTitle,
    required this.priorityScore,
    required this.deadlineUrgency,
    required this.weakness,
    required this.difficulty,
    required this.timeSinceLastStudied,
    required this.recommendedMinutes,
    this.adjustmentReason,
  });

  final String topicId;
  final String topicTitle;
  final String subjectId;
  final String subjectTitle;
  final double priorityScore;

  final double deadlineUrgency;
  final double weakness;
  final double difficulty;
  final double timeSinceLastStudied;

  final int recommendedMinutes;
  final String? adjustmentReason;
}

class StudyPlanAdjustmentResult {
  const StudyPlanAdjustmentResult({
    required this.updatedPlan,
    required this.explanationMessage,
  });

  final List<StudyTaskPriority> updatedPlan;
  final String explanationMessage;
}

