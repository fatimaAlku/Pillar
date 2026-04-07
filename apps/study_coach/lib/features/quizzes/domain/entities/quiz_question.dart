class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.topicId,
    required this.topicTitle,
  }) : assert(options.length == 4, 'QuizQuestion must have exactly 4 options.');

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  /// Used to compute weak topics after submission.
  final String topicId;
  final String topicTitle;
}

