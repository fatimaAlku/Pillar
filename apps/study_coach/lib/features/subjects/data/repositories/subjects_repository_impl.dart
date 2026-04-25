import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/topic_item.dart';
import '../../domain/repositories/subjects_repository.dart';
import '../models/subject_model.dart';

class SubjectsRepositoryImpl implements SubjectsRepository {
  SubjectsRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Subject>> watchSubjects(String uid) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => SubjectModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<TopicItem>> watchTopics({
    required String uid,
    required String subjectId,
  }) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .doc(subjectId)
        .collection(FirestorePaths.topics)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => TopicItem.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<String> createSubject({
    required String uid,
    required String name,
    String examDateIso = '',
    String color = '',
  }) async {
    final ref = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .add({
      'name': name.trim(),
      'examDate': examDateIso,
      'color': color,
    });
    return ref.id;
  }

  @override
  Future<void> updateSubject({
    required String uid,
    required String subjectId,
    required String name,
    String examDateIso = '',
    String? color,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'examDate': examDateIso,
    };
    if (color != null) {
      data['color'] = color;
    }
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .doc(subjectId)
        .update(data);
  }

  @override
  Future<void> deleteSubject({
    required String uid,
    required String subjectId,
  }) async {
    final subjectRef = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .doc(subjectId);
    await _deleteTopicsCollection(subjectRef);
    await subjectRef.delete();
  }

  @override
  Future<String> addTopic({
    required String uid,
    required String subjectId,
    required String title,
    double difficultyEstimate = 0.5,
  }) async {
    final ref = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .doc(subjectId)
        .collection(FirestorePaths.topics)
        .add({
      'title': title.trim(),
      'difficultyEstimate': difficultyEstimate.clamp(0.0, 1.0),
    });
    return ref.id;
  }

  @override
  Future<void> updateTopic({
    required String uid,
    required String subjectId,
    required String topicId,
    required String title,
    double difficultyEstimate = 0.5,
  }) async {
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .doc(subjectId)
        .collection(FirestorePaths.topics)
        .doc(topicId)
        .update({
      'title': title.trim(),
      'difficultyEstimate': difficultyEstimate.clamp(0.0, 1.0),
    });
  }

  @override
  Future<void> deleteTopic({
    required String uid,
    required String subjectId,
    required String topicId,
  }) async {
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .doc(subjectId)
        .collection(FirestorePaths.topics)
        .doc(topicId)
        .delete();
  }

  Future<void> _deleteTopicsCollection(DocumentReference<Object?> subjectRef) async {
    while (true) {
      final snapshot = await subjectRef
          .collection(FirestorePaths.topics)
          .limit(200)
          .get();
      if (snapshot.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
