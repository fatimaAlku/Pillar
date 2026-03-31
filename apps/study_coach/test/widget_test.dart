import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillar_study_coach/app/app.dart';

void main() {
  testWidgets('App renders auth screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyCoachApp()));

    expect(find.text('Pillar'), findsOneWidget);
  });
}
