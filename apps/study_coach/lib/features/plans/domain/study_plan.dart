class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.startDateIso,
    required this.endDateIso,
    required this.status,
  });

  final String id;
  final String startDateIso;
  final String endDateIso;
  final String status;
}
