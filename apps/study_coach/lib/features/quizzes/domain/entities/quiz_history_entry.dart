class QuizHistoryEntry {
  const QuizHistoryEntry({
    required this.id,
    required this.completedAt,
    required this.correctCount,
    required this.totalCount,
    required this.scoreFraction,
    required this.weakTopicTitles,
  });

  final String id;
  final DateTime completedAt;
  final int correctCount;
  final int totalCount;
  final double scoreFraction;
  final List<String> weakTopicTitles;
}
