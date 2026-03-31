class ProgressSnapshot {
  const ProgressSnapshot({
    required this.avgScore,
    required this.weakAreas,
  });

  final double avgScore;
  final List<String> weakAreas;
}
