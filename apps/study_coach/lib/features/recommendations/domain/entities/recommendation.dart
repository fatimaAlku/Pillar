class Recommendation {
  const Recommendation({
    required this.recommendationText,
    required this.generatedAtIso,
    required this.weakAreas,
    required this.strengths,
    this.confidenceByTopic = const {},
    this.quizSampleSize = 0,
  });

  final String recommendationText;
  final String generatedAtIso;
  final List<String> weakAreas;
  final List<String> strengths;
  final Map<String, double> confidenceByTopic;
  final int quizSampleSize;
}
