import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/quiz_question.dart';
import '../../domain/entities/quiz_submission_result.dart';

/// Holds client-side quiz runner state (answer selection, progress, submission).
final quizRunnerControllerProvider =
    StateNotifierProvider<QuizRunnerController, QuizRunnerState>((ref) {
  return QuizRunnerController();
});

sealed class QuizRunnerState {
  const QuizRunnerState();
}

class QuizRunnerInProgress extends QuizRunnerState {
  const QuizRunnerInProgress({
    required this.questions,
    required this.currentIndex,
    required this.selectedByQuestionId,
  });

  final List<QuizQuestion> questions;
  final int currentIndex;

  /// questionId -> selected option index (0-3)
  final Map<String, int> selectedByQuestionId;

  int get totalCount => questions.length;
  int get questionNumber => currentIndex + 1;

  QuizQuestion get currentQuestion => questions[currentIndex];

  int? selectedFor(String questionId) => selectedByQuestionId[questionId];

  bool get isLastQuestion => currentIndex >= questions.length - 1;
  bool get isFirstQuestion => currentIndex <= 0;

  bool get canSubmit => questions.isNotEmpty;

  QuizRunnerInProgress copyWith({
    List<QuizQuestion>? questions,
    int? currentIndex,
    Map<String, int>? selectedByQuestionId,
  }) {
    return QuizRunnerInProgress(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedByQuestionId: selectedByQuestionId ?? this.selectedByQuestionId,
    );
  }
}

class QuizRunnerSubmitted extends QuizRunnerState {
  const QuizRunnerSubmitted(this.result);
  final QuizSubmissionResult result;
}

class QuizRunnerController extends StateNotifier<QuizRunnerState> {
  QuizRunnerController() : super(_initial());

  static QuizRunnerState _initial() {
    // Temporary local data so the full quiz system works end-to-end.
    // This can later be replaced by generated/persisted questions (Firestore/Functions).
    const questions = <QuizQuestion>[
      QuizQuestion(
        id: 'q1',
        topicId: 'topic_bst',
        topicTitle: 'Binary Search Trees',
        prompt: 'In a BST, which traversal outputs keys in sorted order?',
        options: ['Preorder', 'Inorder', 'Postorder', 'Level order'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'q2',
        topicId: 'topic_bst',
        topicTitle: 'Binary Search Trees',
        prompt: 'What is the average time complexity of search in a balanced BST?',
        options: ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'q3',
        topicId: 'topic_hashing',
        topicTitle: 'Hashing',
        prompt: 'Which technique resolves collisions by scanning for the next slot?',
        options: ['Chaining', 'Open addressing', 'Perfect hashing', 'Compression'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'q4',
        topicId: 'topic_heaps',
        topicTitle: 'Heaps',
        prompt: 'In a max-heap, the parent node is ____ its children.',
        options: ['<=', '>=', '==', 'Unrelated to'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'q5',
        topicId: 'topic_graphs',
        topicTitle: 'Graphs',
        prompt: 'BFS is commonly used to find the ____ path in an unweighted graph.',
        options: ['Longest', 'Shortest', 'Most expensive', 'Random'],
        correctIndex: 1,
      ),
    ];

    return const QuizRunnerInProgress(
      questions: questions,
      currentIndex: 0,
      selectedByQuestionId: {},
    );
  }

  void restart() {
    state = _initial();
  }

  void selectOption({
    required String questionId,
    required int optionIndex,
  }) {
    final current = state;
    if (current is! QuizRunnerInProgress) return;

    final nextSelected = Map<String, int>.from(current.selectedByQuestionId)
      ..[questionId] = optionIndex;

    state = current.copyWith(selectedByQuestionId: nextSelected);
  }

  void next() {
    final current = state;
    if (current is! QuizRunnerInProgress) return;
    if (current.isLastQuestion) return;
    state = current.copyWith(currentIndex: current.currentIndex + 1);
  }

  void previous() {
    final current = state;
    if (current is! QuizRunnerInProgress) return;
    if (current.isFirstQuestion) return;
    state = current.copyWith(currentIndex: current.currentIndex - 1);
  }

  void jumpTo(int index) {
    final current = state;
    if (current is! QuizRunnerInProgress) return;
    if (index < 0 || index >= current.questions.length) return;
    state = current.copyWith(currentIndex: index);
  }

  void submit() {
    final current = state;
    if (current is! QuizRunnerInProgress) return;

    final questions = current.questions;
    final selected = current.selectedByQuestionId;

    var correctCount = 0;
    final incorrectByTopicId = <String, WeakTopic>{};

    for (final q in questions) {
      final selectedIndex = selected[q.id];
      final isCorrect = selectedIndex != null && selectedIndex == q.correctIndex;
      if (isCorrect) {
        correctCount += 1;
      } else {
        final existing = incorrectByTopicId[q.topicId];
        incorrectByTopicId[q.topicId] = WeakTopic(
          topicId: q.topicId,
          topicTitle: q.topicTitle,
          incorrectCount: (existing?.incorrectCount ?? 0) + 1,
        );
      }
    }

    final weakTopics = incorrectByTopicId.values.toList()
      ..sort((a, b) => b.incorrectCount.compareTo(a.incorrectCount));

    state = QuizRunnerSubmitted(
      QuizSubmissionResult(
        questions: questions,
        selectedByQuestionId: selected,
        correctCount: correctCount,
        totalCount: questions.length,
        weakTopics: weakTopics,
      ),
    );
  }
}
