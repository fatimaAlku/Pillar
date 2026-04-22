import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillar_study_coach/app/app.dart';
import 'package:pillar_study_coach/core/state/app_providers.dart';
import 'package:pillar_study_coach/features/auth/domain/entities/auth_user.dart';
import 'package:pillar_study_coach/features/quizzes/data/services/quiz_ai_service.dart';
import 'package:pillar_study_coach/features/quizzes/domain/entities/quiz_question.dart';

void main() {
  testWidgets('Unauthenticated users land on login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDelayProvider.overrideWith((ref) async {}),
          currentAuthUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Need an account? Sign up'), findsOneWidget);
    expect(find.text('Pillar'), findsOneWidget);
  });

  testWidgets('Authenticated users can open each dashboard tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDelayProvider.overrideWith((ref) async {}),
          currentAuthUserProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(uid: 'test-user-1', email: 'test@example.com'),
            ),
          ),
          quizAiServiceProvider.overrideWithValue(_NoopQuizAiService()),
        ],
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Computer Science'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('test'), findsOneWidget);
  });

  testWidgets('Roadmap major card opens detailed roadmap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupDelayProvider.overrideWith((ref) async {}),
          currentAuthUserProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(uid: 'test-user-2', email: 'roadmap@example.com'),
            ),
          ),
          quizAiServiceProvider.overrideWithValue(_NoopQuizAiService()),
        ],
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Computer Science'));
    await tester.pumpAndSettle();

    expect(find.text('Computer Science Roadmap'), findsOneWidget);
    expect(find.text('Priority roadmap'), findsOneWidget);
    expect(find.text('Programming Foundations'), findsOneWidget);
  });
}

class _NoopQuizAiService implements QuizAiService {
  @override
  Future<List<QuizQuestion>> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
  }) async {
    return const [];
  }
}
