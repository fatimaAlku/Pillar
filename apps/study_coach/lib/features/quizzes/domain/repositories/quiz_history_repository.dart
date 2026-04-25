import '../entities/quiz_history_entry.dart';
import '../entities/quiz_submission_result.dart';

abstract class QuizHistoryRepository {
  Future<void> saveAttempt({
    required String uid,
    required QuizSubmissionResult result,
    required DateTime completedAt,
  });

  Stream<List<QuizHistoryEntry>> watchHistory(String uid, {int limit = 30});
}
