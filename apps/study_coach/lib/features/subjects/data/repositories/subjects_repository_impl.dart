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
}
