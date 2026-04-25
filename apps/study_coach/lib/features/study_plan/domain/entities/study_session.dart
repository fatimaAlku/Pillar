class StudySession {
  const StudySession({
    required this.id,
    required this.planId,
    required this.topicId,
    required this.date,
    required this.durationMin,
    required this.startMinute,
    required this.completed,
  });

  final String id;
  final String planId;
  final String topicId;
  final String date;
  final int durationMin;
  final int? startMinute;
  final bool completed;
}
