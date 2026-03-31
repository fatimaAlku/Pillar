import '../entities/subject.dart';

abstract class SubjectsRepository {
  Stream<List<Subject>> watchSubjects(String uid);
}
