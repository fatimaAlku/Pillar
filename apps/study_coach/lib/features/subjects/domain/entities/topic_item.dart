class TopicItem {
  const TopicItem({
    required this.id,
    required this.title,
    required this.difficultyEstimate,
  });

  final String id;
  final String title;
  final double difficultyEstimate;

  factory TopicItem.fromFirestore(String id, Map<String, dynamic> data) {
    final rawTitle = (data['title'] as String?)?.trim() ?? '';
    final raw = data['difficultyEstimate'];
    final difficulty = raw is num
        ? raw.toDouble().clamp(0.0, 1.0)
        : 0.5;
    return TopicItem(
      id: id,
      title: rawTitle.isEmpty ? 'Topic' : rawTitle,
      difficultyEstimate: difficulty,
    );
  }
}
