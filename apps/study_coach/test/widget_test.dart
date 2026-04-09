import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillar_study_coach/app/app.dart';

void main() {
  testWidgets('App renders auth screen title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [startupDelayProvider.overrideWith((ref) async {})],
        child: const StudyCoachApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Pillar'), findsOneWidget);
  });
}
