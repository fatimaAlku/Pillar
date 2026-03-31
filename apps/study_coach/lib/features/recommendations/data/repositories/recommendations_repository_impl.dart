import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/repositories/recommendations_repository.dart';

class RecommendationsRepositoryImpl implements RecommendationsRepository {
  RecommendationsRepositoryImpl(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> generateRecommendations() async {
    await _functions.httpsCallable('generateRecommendations').call();
  }
}
