/// Aggregated session-history signals for a single topic. Used to enrich
/// [TopicPerformanceInput] with recency and missed-session info that the
/// dynamic planner relies on.
class TopicActivitySignals {
  const TopicActivitySignals({
    required this.lastStudiedAt,
    required this.missedSessions,
    required this.completedSessions,
  });

  /// Most recent completed-session timestamp for the topic, or `null` when
  /// the topic has no completed sessions in the lookback window.
  final DateTime? lastStudiedAt;

  /// Past-dated sessions that were never marked complete in the lookback
  /// window. Drives the dynamic "missed sessions" boost in the planner.
  final int missedSessions;

  /// Past-dated sessions that the user did complete. Used for downstream
  /// momentum signals and "studied today" hints in the UI.
  final int completedSessions;

  static const empty = TopicActivitySignals(
    lastStudiedAt: null,
    missedSessions: 0,
    completedSessions: 0,
  );
}
