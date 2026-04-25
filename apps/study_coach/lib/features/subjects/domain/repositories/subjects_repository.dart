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

  Future<void> updateSubject({
    required String uid,
    required String subjectId,
    required String name,
    String examDateIso = '',
    String? color,
  });

  Future<void> deleteSubject({
    required String uid,
    required String subjectId,
  });

  /// Creates `users/{uid}/subjects/{subjectId}/topics/{autoId}`; returns topic id.
  Future<String> addTopic({
    required String uid,
    required String subjectId,
    required String title,
    double difficultyEstimate = 0.5,
  });

  Future<void> updateTopic({
    required String uid,
    required String subjectId,
    required String topicId,
    required String title,
    double difficultyEstimate = 0.5,
  });

  Future<void> deleteTopic({
    required String uid,
    required String subjectId,
    required String topicId,
  });
}
