class StudySession {
  const StudySession({
    required this.id,
    required this.topicId,
    required this.dateIso,
    required this.durationMin,
  });

  final String id;
  final String topicId;
  final String dateIso;
  final int durationMin;
}
