import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/repositories/quizzes_repository.dart';

class QuizzesRepositoryImpl implements QuizzesRepository {
  QuizzesRepositoryImpl(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> generateQuiz({
    required List<String> topicIds,
    String? notesText,
  }) async {
    await _functions.httpsCallable('generateQuiz').call(<String, dynamic>{
      'topicIds': topicIds,
      'notesText': notesText,
    });
  }

  @override
  Future<void> submitQuizAttempt({
    required String quizId,
    required double score,
    required List<String> weakTags,
  }) async {
    await _functions.httpsCallable('submitQuizAttempt').call(<String, dynamic>{
      'quizId': quizId,
      'score': score,
      'weakTags': weakTags,
    });
  }
}
