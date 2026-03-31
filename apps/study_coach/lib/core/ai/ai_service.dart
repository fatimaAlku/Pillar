import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  AiService(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> generateQuiz({
    required List<String> topicIds,
    String? notesText,
  }) async {
    final callable = _functions.httpsCallable('generateQuiz');
    final result = await callable.call(<String, dynamic>{
      'topicIds': topicIds,
      'notesText': notesText,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> generateRecommendations() async {
    final callable = _functions.httpsCallable('generateRecommendations');
    final result = await callable.call();
    return Map<String, dynamic>.from(result.data as Map);
  }
}
