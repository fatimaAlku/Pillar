import 'quiz_question.dart';

/// Optional link to a Firestore **course (subject)** and **topic** documents.
/// When set, history and reports can show which course the weak-topic signal
/// belongs to.
class QuizLinkContext {
  const QuizLinkContext({
    required this.subjectId,
    required this.subjectTitle,
    this.linkedTopicIds = const [],
    this.linkedTopicTitles = const [],
  });

  final String subjectId;
  final String subjectTitle;

  /// Doc ids under `subjects/{subjectId}/topics/{id}`.
  final List<String> linkedTopicIds;

  /// Display titles in the same order as [linkedTopicIds].
  final List<String> linkedTopicTitles;

  bool get hasSubject => subjectId.trim().isNotEmpty;

  String get displayLine {
    final course = subjectTitle.trim();
    final topics = linkedTopicTitles
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
    if (course.isEmpty && topics.isEmpty) return '';
    if (topics.isEmpty) return course;
    if (course.isEmpty) return topics;
    return '$course — $topics';
  }
}

class QuizSubmissionResult {
  const QuizSubmissionResult({
    required this.questions,
    required this.selectedByQuestionId,
    required this.correctCount,
    required this.totalCount,
    required this.weakTopics,
    this.linkContext,
  });

  final List<QuizQuestion> questions;

  /// Map: questionId -> selected option index (0-3). Missing means unanswered.
  final Map<String, int> selectedByQuestionId;

  final int correctCount;
  final int totalCount;

  /// Ordered list of weak topics (most wrong first).
  final List<WeakTopic> weakTopics;

  /// When the quiz was generated with a course/topic link from My courses.
  final QuizLinkContext? linkContext;

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

