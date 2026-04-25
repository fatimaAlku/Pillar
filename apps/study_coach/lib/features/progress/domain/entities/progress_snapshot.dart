class ProgressSnapshot {
  const ProgressSnapshot({
    required this.overallProgress,
    required this.roadmapCompletion,
    required this.sessionsCompletion,
    required this.avgScore,
    required this.weakAreas,
    required this.majorId,
  });

  final double overallProgress;
  final double roadmapCompletion;
  final double sessionsCompletion;
  final double avgScore;
  final List<String> weakAreas;
  final String? majorId;

  static const empty = ProgressSnapshot(
    overallProgress: 0,
    roadmapCompletion: 0,
    sessionsCompletion: 0,
    avgScore: 0,
    weakAreas: <String>[],
    majorId: null,
  );
}
