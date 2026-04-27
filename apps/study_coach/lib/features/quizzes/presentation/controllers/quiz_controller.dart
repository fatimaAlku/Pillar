import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_locale_controller.dart';
import '../../../../core/state/app_providers.dart';
import '../../data/services/quiz_ai_service.dart';
import '../../domain/entities/quiz_question.dart';
import '../../domain/entities/quiz_submission_result.dart';
import '../../domain/repositories/quiz_history_repository.dart';

/// Holds client-side quiz runner state (answer selection, progress, submission).
final quizRunnerControllerProvider =
    StateNotifierProvider<QuizRunnerController, QuizRunnerState>((ref) {
  return QuizRunnerController(
    ref.watch(quizAiServiceProvider),
    ref.watch(quizHistoryRepositoryProvider),
    () => ref.read(currentAuthUserProvider).valueOrNull?.uid,
    () => ref.read(appLocaleProvider).languageCode,
  );
});

sealed class QuizRunnerState {
  const QuizRunnerState();
}

class QuizRunnerIdle extends QuizRunnerState {
  const QuizRunnerIdle();
}

class QuizRunnerLoading extends QuizRunnerState {
  const QuizRunnerLoading();
}

class QuizRunnerError extends QuizRunnerState {
  const QuizRunnerError(this.message);
  final String message;
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

class QuizGenerationRequest {
  const QuizGenerationRequest({
    required this.topics,
    required this.difficulty,
    required this.numberOfQuestions,
    this.notesText,
  });

  final List<String> topics;
  final String difficulty;
  final int numberOfQuestions;
  final String? notesText;
}

class QuizRunnerController extends StateNotifier<QuizRunnerState> {
  QuizRunnerController(
    this._quizAiService,
    this._quizHistoryRepository,
    this._currentUserId,
    this._currentLanguageCode,
  ) : super(const QuizRunnerIdle());
  static const Duration _generationTimeout = Duration(seconds: 70);

  final QuizAiService _quizAiService;
  final QuizHistoryRepository _quizHistoryRepository;
  final String? Function() _currentUserId;
  final String Function() _currentLanguageCode;
  QuizGenerationRequest? _lastRequest;
  List<QuizQuestion>? _lastGeneratedQuestions;

  void restart() {
    final questions = _lastGeneratedQuestions;
    if (questions == null || questions.isEmpty) {
      state = const QuizRunnerIdle();
      return;
    }
    state = QuizRunnerInProgress(
      questions: questions,
      currentIndex: 0,
      selectedByQuestionId: const {},
    );
  }

  void resetSession() {
    _lastRequest = null;
    _lastGeneratedQuestions = null;
    state = const QuizRunnerIdle();
  }

  Future<void> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
  }) async {
    final trimmedTopics =
        topics.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final normalizedNotes = notesText?.trim();

    _lastRequest = QuizGenerationRequest(
      topics: trimmedTopics,
      difficulty: difficulty.trim(),
      numberOfQuestions: numberOfQuestions,
      notesText: normalizedNotes?.isEmpty == true ? null : normalizedNotes,
    );

    state = const QuizRunnerLoading();

    try {
      final questions = await _quizAiService
          .generateQuiz(
        topics: trimmedTopics,
        difficulty: difficulty,
        numberOfQuestions: numberOfQuestions,
        notesText: normalizedNotes,
        languageCode: _currentLanguageCode(),
      )
          .timeout(_generationTimeout, onTimeout: () {
        throw const QuizAiServiceException(
          'Quiz generation is taking too long. Please try again.',
        );
      });

      _lastGeneratedQuestions = questions;
      state = QuizRunnerInProgress(
        questions: questions,
        currentIndex: 0,
        selectedByQuestionId: const {},
      );
    } on QuizAiServiceException catch (e) {
      final details = e.details?.trim();
      if (details != null && details.isNotEmpty) {
        state = QuizRunnerError('${e.message} $details');
      } else {
        state = QuizRunnerError(e.message);
      }
    } on QuizAiException catch (e) {
      state = QuizRunnerError(e.message);
    } catch (_) {
      state =
          const QuizRunnerError('Failed to generate quiz. Please try again.');
    }
  }

  Future<void> retryLastGeneration() async {
    final request = _lastRequest;
    if (request == null) return;
    await generateQuiz(
      topics: request.topics,
      difficulty: request.difficulty,
      numberOfQuestions: request.numberOfQuestions,
      notesText: request.notesText,
    );
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
      final isCorrect =
          selectedIndex != null && selectedIndex == q.correctIndex;
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

    final result = QuizSubmissionResult(
      questions: questions,
      selectedByQuestionId: selected,
      correctCount: correctCount,
      totalCount: questions.length,
      weakTopics: weakTopics,
    );
    state = QuizRunnerSubmitted(result);
    unawaited(_persistHistory(result));
  }

  Future<void> _persistHistory(QuizSubmissionResult result) async {
    final uid = _currentUserId()?.trim();
    if (uid == null || uid.isEmpty) return;
    try {
      await _quizHistoryRepository.saveAttempt(
        uid: uid,
        result: result,
        completedAt: DateTime.now(),
      );
    } catch (_) {
      // History persistence failure should not block quiz submission UX.
    }
  }
}
