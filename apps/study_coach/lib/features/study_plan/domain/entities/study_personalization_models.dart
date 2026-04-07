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
}

class StudyPlanPersonalizationInput {
  const StudyPlanPersonalizationInput({
    required this.topics,
    required this.availableStudyMinutes,
    required this.now,
  });

  final List<TopicPerformanceInput> topics;
  final int availableStudyMinutes;
  final DateTime now;
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
}

