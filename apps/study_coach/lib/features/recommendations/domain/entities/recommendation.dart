class Recommendation {
  const Recommendation({
    required this.recommendationText,
    required this.generatedAtIso,
    required this.weakAreas,
    required this.strengths,
  });

  final String recommendationText;
  final String generatedAtIso;
  final List<String> weakAreas;
  final List<String> strengths;
}
