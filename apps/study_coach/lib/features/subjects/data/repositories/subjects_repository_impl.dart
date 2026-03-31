import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/subject.dart';
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
}
