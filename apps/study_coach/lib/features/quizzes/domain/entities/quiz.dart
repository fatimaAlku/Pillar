class Quiz {
  const Quiz({
    required this.id,
    required this.questionCount,
    required this.generatedAtIso,
  });

  final String id;
  final int questionCount;
  final String generatedAtIso;
}
