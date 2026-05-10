import 'package:flutter_test/flutter_test.dart';

import '../lib/features/quizzes/data/services/quiz_ai_service.dart';

void main() {
  Map<String, dynamic> payload(List<Map<String, dynamic>> qs) =>
      <String, dynamic>{'questions': qs};

  Map<String, dynamic> q({
    required String prompt,
    required String topicTitle,
    List<String> options = const ['a', 'b', 'c', 'd'],
    int correctIndex = 0,
  }) {
    return <String, dynamic>{
      'prompt': prompt,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': 'because',
      'topicTitle': topicTitle,
    };
  }

  group('QuizAiResponseParser canonical topic snapping', () {
    test('exact case-insensitive match wins', () {
      final out = QuizAiResponseParser.parseToQuestions(
        data: payload([
          q(prompt: 'Hash function collisions?', topicTitle: 'hashing'),
        ]),
        fallbackTopic: 'CS',
        allowedTopics: const <String>['Trees', 'Hashing'],
      );

      expect(out, hasLength(1));
      expect(out.single.topicTitle, 'Hashing');
      expect(out.single.topicId, 'topic_hashing');
    });

    test('substring match collapses generic AI variant onto allowed topic',
        () {
      final out = QuizAiResponseParser.parseToQuestions(
        data: payload([
          q(prompt: 'Pre-order vs in-order traversal?',
              topicTitle: 'Binary Trees and Traversals'),
        ]),
        fallbackTopic: 'CS',
        allowedTopics: const <String>['Trees', 'Hashing'],
      );

      expect(out.single.topicTitle, 'Trees');
    });

    test('snaps generic AI label using prompt when topicTitle is unhelpful',
        () {
      final out = QuizAiResponseParser.parseToQuestions(
        data: payload([
          q(prompt: 'Which traversal visits left, root, right in a Tree?',
              topicTitle: 'Common beginner mistakes'),
          q(prompt: 'A hash table resolves collisions using chaining',
              topicTitle: 'General'),
        ]),
        fallbackTopic: 'CS',
        allowedTopics: const <String>['Trees', 'Hashing'],
      );

      expect(out.map((e) => e.topicTitle), <String>['Trees', 'Hashing']);
      expect(out.map((e) => e.topicId),
          <String>['topic_trees', 'topic_hashing']);
    });

    test('falls back to first allowed topic when nothing matches', () {
      final out = QuizAiResponseParser.parseToQuestions(
        data: payload([
          q(prompt: 'Mitochondria are the powerhouse of the cell.',
              topicTitle: 'Misc'),
        ]),
        fallbackTopic: 'CS',
        allowedTopics: const <String>['Trees', 'Hashing'],
      );

      expect(out.single.topicTitle, 'Trees');
      expect(out.single.topicId, 'topic_trees');
    });

    test('no allowed topics keeps AI title, defaults to fallback when empty',
        () {
      final out = QuizAiResponseParser.parseToQuestions(
        data: payload([
          q(prompt: 'Define recursion.', topicTitle: 'Recursion 101'),
          q(prompt: 'Define iteration.', topicTitle: ''),
        ]),
        fallbackTopic: 'CS Foundations',
      );

      expect(out[0].topicTitle, 'Recursion 101');
      expect(out[1].topicTitle, 'CS Foundations');
    });
  });
}
