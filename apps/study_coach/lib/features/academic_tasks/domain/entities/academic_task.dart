enum AcademicTaskType {
  homework,
  project,
  quiz,
  lab,
  presentation,
  reading,
  exam,
  semesterDeadline,
  other,
}

enum AcademicTaskPriority {
  low,
  medium,
  high,
}

enum AcademicTaskStatus {
  open,
  completed,
  archived,
}

class AcademicTask {
  const AcademicTask({
    required this.id,
    required this.title,
    required this.type,
    required this.dueDateIso,
    this.subjectId = '',
    this.estimatedMinutes = 60,
    this.priority = AcademicTaskPriority.medium,
    this.status = AcademicTaskStatus.open,
    this.notes = '',
    this.createdAtIso = '',
    this.updatedAtIso = '',
    this.completedAtIso = '',
  });

  final String id;
  final String title;
  final AcademicTaskType type;
  final String subjectId;
  final String dueDateIso;
  final int estimatedMinutes;
  final AcademicTaskPriority priority;
  final AcademicTaskStatus status;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;
  final String completedAtIso;

  DateTime? get dueDate => DateTime.tryParse(dueDateIso);

  bool get isCompleted => status == AcademicTaskStatus.completed;
}
