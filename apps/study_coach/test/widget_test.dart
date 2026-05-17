import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillar_study_coach/app/app.dart';

import 'support/test_app_overrides.dart';

void main() {
  testWidgets('App renders auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: unauthenticatedAppOverrides(),
        child: const StudyCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Sign up'), findsWidgets);
  });
}
