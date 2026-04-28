import '../entities/recommendation.dart';

abstract class RecommendationsRepository {
  Future<void> generateRecommendations();

  Stream<Recommendation?> watchLatestRecommendation(String uid);
}
