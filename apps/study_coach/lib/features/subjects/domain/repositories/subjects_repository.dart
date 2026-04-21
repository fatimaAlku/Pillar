import '../entities/subject.dart';
import '../entities/topic_item.dart';

abstract class SubjectsRepository {
  Stream<List<Subject>> watchSubjects(String uid);

  Stream<List<TopicItem>> watchTopics({
    required String uid,
    required String subjectId,
  });

  /// Creates `users/{uid}/subjects/{autoId}`; returns the new document id.
  Future<String> createSubject({
    required String uid,
    required String name,
    String examDateIso = '',
    String color = '',
  });

  /// Creates `users/{uid}/subjects/{subjectId}/topics/{autoId}`; returns topic id.
  Future<String> addTopic({
    required String uid,
    required String subjectId,
    required String title,
    double difficultyEstimate = 0.5,
  });
}
