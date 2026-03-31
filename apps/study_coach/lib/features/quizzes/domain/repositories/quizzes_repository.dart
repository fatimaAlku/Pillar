abstract class QuizzesRepository {
  Future<void> generateQuiz({
    required List<String> topicIds,
    String? notesText,
  });

  Future<void> submitQuizAttempt({
    required String quizId,
    required double score,
    required List<String> weakTags,
  });
}
