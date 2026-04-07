import 'quiz_question.dart';

class QuizSubmissionResult {
  const QuizSubmissionResult({
    required this.questions,
    required this.selectedByQuestionId,
    required this.correctCount,
    required this.totalCount,
    required this.weakTopics,
  });

  final List<QuizQuestion> questions;

  /// Map: questionId -> selected option index (0-3). Missing means unanswered.
  final Map<String, int> selectedByQuestionId;

  final int correctCount;
  final int totalCount;

  /// Ordered list of weak topics (most wrong first).
  final List<WeakTopic> weakTopics;

  double get scoreFraction => totalCount == 0 ? 0 : correctCount / totalCount;
}

class WeakTopic {
  const WeakTopic({
    required this.topicId,
    required this.topicTitle,
    required this.incorrectCount,
  });

  final String topicId;
  final String topicTitle;
  final int incorrectCount;
}

