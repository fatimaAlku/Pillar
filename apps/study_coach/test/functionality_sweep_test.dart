import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillar_study_coach/app/app.dart';
import 'package:pillar_study_coach/features/auth/domain/entities/auth_user.dart';
import 'support/test_app_overrides.dart';

void main() {
  testWidgets('Unauthenticated users land on login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: unauthenticatedAppOverrides(),
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Need an account? Sign up'), findsOneWidget);
    expect(find.text('Sign up'), findsWidgets);
  });

  testWidgets('Authenticated users can open each dashboard tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedAppOverrides(
          user: const AuthUser(
            uid: 'test-user-1',
            email: 'test@gmail.com',
            displayName: 'test',
          ),
        ),
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Question style'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Computer Science'), findsWidgets);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('test'), findsOneWidget);
  });

  testWidgets('Roadmap tab shows major from profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedAppOverrides(
          user: const AuthUser(
            uid: 'test-user-2',
            email: 'roadmap@gmail.com',
          ),
        ),
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Computer Science'), findsWidgets);
    expect(find.text('Open full roadmap'), findsOneWidget);
    expect(find.text('What you will cover'), findsOneWidget);
  });
}
