import 'package:flutter_test/flutter_test.dart';
import 'package:pillar_study_coach/features/study_plan/domain/entities/study_personalization_models.dart';
import 'package:pillar_study_coach/features/study_plan/domain/services/study_plan_personalization_service.dart';

void main() {
  const service = StudyPlanPersonalizationService();
  final now = DateTime(2026, 5, 9, 10);

  TopicPerformanceInput topic({
    required String id,
    required double quizAccuracy,
    required int daysUntilExam,
    double difficulty = 0.5,
    DateTime? lastStudiedAt,
    int missedSessions = 0,
    String subjectId = 'subject',
  }) {
    return TopicPerformanceInput(
      topicId: id,
      topicTitle: 'Topic $id',
      subjectId: subjectId,
      subjectTitle: 'Subject $subjectId',
      examDate: now.add(Duration(days: daysUntilExam)),
      quizAccuracy: quizAccuracy,
      subjectDifficulty: difficulty,
      lastStudiedAt: lastStudiedAt,
      missedSessions: missedSessions,
    );
  }

  StudyPlanPersonalizationInput inputFor({
    required List<TopicPerformanceInput> topics,
    required int budgetMinutes,
  }) {
    return StudyPlanPersonalizationInput(
      topics: topics,
      availableStudyMinutes: budgetMinutes,
      now: now,
    );
  }

  test('returns no plan when there are no topics or no time budget', () {
    final emptyTopics = service.buildDynamicPlan(
      inputFor(topics: const [], budgetMinutes: 120),
    );
    expect(emptyTopics.updatedPlan, isEmpty);
    expect(emptyTopics.explanationMessage, isNotEmpty);

    final zeroBudget = service.buildDynamicPlan(
      inputFor(
        topics: [topic(id: 'a', quizAccuracy: 0.5, daysUntilExam: 14)],
        budgetMinutes: 0,
      ),
    );
    expect(zeroBudget.updatedPlan, isEmpty);
  });

  test('low quiz performance + soon exam outranks healthy topic far away', () {
    final result = service.buildDynamicPlan(
      inputFor(
        budgetMinutes: 180,
        topics: [
          topic(
            id: 'weak-soon',
            quizAccuracy: 0.25,
            daysUntilExam: 4,
            lastStudiedAt: now.subtract(const Duration(days: 8)),
            subjectId: 'soon',
          ),
          topic(
            id: 'strong-far',
            quizAccuracy: 0.92,
            daysUntilExam: 45,
            lastStudiedAt: now.subtract(const Duration(days: 1)),
            subjectId: 'far',
          ),
        ],
      ),
    );

    expect(result.updatedPlan.first.topicId, 'weak-soon');
    expect(
      result.updatedPlan.first.recommendedMinutes,
      greaterThan(result.updatedPlan.last.recommendedMinutes),
    );
    expect(
      result.updatedPlan.first.adjustmentReason,
      'low quiz performance',
    );
    expect(
      result.explanationMessage,
      contains('Topic weak-soon'),
    );
  });

  test('total recommended minutes never exceed the daily time budget', () {
    final budgets = [30, 60, 90, 120, 180, 240, 360];
    final topics = [
      topic(id: 'a', quizAccuracy: 0.4, daysUntilExam: 6),
      topic(id: 'b', quizAccuracy: 0.7, daysUntilExam: 14),
      topic(id: 'c', quizAccuracy: 0.55, daysUntilExam: 9, missedSessions: 2),
      topic(id: 'd', quizAccuracy: 0.85, daysUntilExam: 30),
    ];

    for (final budget in budgets) {
      final plan = service.buildDynamicPlan(
        inputFor(topics: topics, budgetMinutes: budget),
      );
      final total = plan.updatedPlan
          .fold<int>(0, (acc, item) => acc + item.recommendedMinutes);
      expect(total, lessThanOrEqualTo(budget),
          reason: 'budget=$budget overshot total=$total');
      // Highest priority topic should always get at least one focused block
      // when the budget can afford it.
      if (budget >= 30) {
        expect(plan.updatedPlan.first.recommendedMinutes, greaterThanOrEqualTo(15));
      }
    }
  });

  test('small budgets concentrate minutes on top priorities', () {
    final result = service.buildDynamicPlan(
      inputFor(
        budgetMinutes: 60,
        topics: [
          topic(id: 'a', quizAccuracy: 0.3, daysUntilExam: 5),
          topic(id: 'b', quizAccuracy: 0.6, daysUntilExam: 14),
          topic(id: 'c', quizAccuracy: 0.85, daysUntilExam: 30),
          topic(id: 'd', quizAccuracy: 0.95, daysUntilExam: 45),
        ],
      ),
    );

    final totalsByTopic = {
      for (final task in result.updatedPlan) task.topicId: task.recommendedMinutes,
    };
    expect(totalsByTopic['a'], greaterThan(0));
    // With a 60-minute budget and 20-minute minimum sessions, there should
    // be at most three topics with minutes assigned.
    final allocated =
        result.updatedPlan.where((t) => t.recommendedMinutes > 0).length;
    expect(allocated, lessThanOrEqualTo(3));
  });

  test('missed sessions shift minutes from low-priority donors', () {
    final baseline = service.buildDynamicPlan(
      inputFor(
        budgetMinutes: 180,
        topics: [
          topic(id: 'a', quizAccuracy: 0.7, daysUntilExam: 12),
          topic(id: 'b', quizAccuracy: 0.65, daysUntilExam: 18),
          topic(id: 'c', quizAccuracy: 0.6, daysUntilExam: 25),
        ],
      ),
    );
    final missed = service.buildDynamicPlan(
      inputFor(
        budgetMinutes: 180,
        topics: [
          topic(id: 'a', quizAccuracy: 0.7, daysUntilExam: 12, missedSessions: 3),
          topic(id: 'b', quizAccuracy: 0.65, daysUntilExam: 18),
          topic(id: 'c', quizAccuracy: 0.6, daysUntilExam: 25),
        ],
      ),
    );

    int minutesFor(StudyPlanAdjustmentResult result, String id) {
      return result.updatedPlan
          .firstWhere((task) => task.topicId == id)
          .recommendedMinutes;
    }

    expect(minutesFor(missed, 'a'), greaterThan(minutesFor(baseline, 'a')));
    expect(missed.updatedPlan.first.adjustmentReason, isNotNull);
    expect(missed.updatedPlan.first.adjustmentReason, isNotEmpty);
  });

  test('long time since last study triggers stale reason for healthy topics', () {
    final result = service.buildDynamicPlan(
      inputFor(
        budgetMinutes: 90,
        topics: [
          topic(
            id: 'fresh',
            quizAccuracy: 0.9,
            daysUntilExam: 30,
            lastStudiedAt: now.subtract(const Duration(days: 1)),
            subjectId: 's1',
          ),
          topic(
            id: 'stale',
            quizAccuracy: 0.9,
            daysUntilExam: 30,
            lastStudiedAt: now.subtract(const Duration(days: 12)),
            subjectId: 's2',
          ),
        ],
      ),
    );

    final stale =
        result.updatedPlan.firstWhere((t) => t.topicId == 'stale');
    expect(stale.adjustmentReason, 'long time since last study');
    expect(stale.timeSinceLastStudied, greaterThan(0.5));
  });

  test('unknown lastStudiedAt is treated as maximally stale', () {
    final result = service.buildDynamicPlan(
      inputFor(
        budgetMinutes: 60,
        topics: [
          topic(
            id: 'never',
            quizAccuracy: 0.85,
            daysUntilExam: 30,
            lastStudiedAt: null,
          ),
          topic(
            id: 'recent',
            quizAccuracy: 0.85,
            daysUntilExam: 30,
            lastStudiedAt: now,
          ),
        ],
      ),
    );

    expect(result.updatedPlan.first.topicId, 'never');
    expect(result.updatedPlan.first.timeSinceLastStudied, 1.0);
  });
}
