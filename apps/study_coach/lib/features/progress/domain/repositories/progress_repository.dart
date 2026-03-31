import '../entities/progress_snapshot.dart';

abstract class ProgressRepository {
  Stream<ProgressSnapshot> watchProgress(String uid);
}
