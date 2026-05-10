class QuizHistoryEntry {
  const QuizHistoryEntry({
    required this.id,
    required this.completedAt,
    required this.correctCount,
    required this.totalCount,
    required this.scoreFraction,
    required this.weakTopicTitles,
    this.linkedSubjectId,
    this.linkedSubjectTitle,
    this.linkedTopicIds = const [],
    this.linkedTopicTitles = const [],
  });

  final String id;
  final DateTime completedAt;
  final int correctCount;
  final int totalCount;
  final double scoreFraction;
  final List<String> weakTopicTitles;

  /// Firestore subject (course) doc id when the quiz was linked at generation time.
  final String? linkedSubjectId;

  /// Course display name.
  final String? linkedSubjectTitle;

  /// Topic doc ids under that subject.
  final List<String> linkedTopicIds;

  /// Parallel titles for [linkedTopicIds].
  final List<String> linkedTopicTitles;
}
