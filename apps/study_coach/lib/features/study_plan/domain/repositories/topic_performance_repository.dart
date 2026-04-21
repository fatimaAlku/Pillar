import '../entities/study_personalization_models.dart';

abstract class TopicPerformanceRepository {
  Stream<List<TopicPerformanceInput>> watchTopicPerformanceInputs(String uid);
}
