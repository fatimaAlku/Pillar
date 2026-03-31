import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillar_study_coach/app/app.dart';

void main() {
  testWidgets('App renders root title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyCoachApp()));

    expect(find.text('Pillar AI Study Coach'), findsOneWidget);
  });
}
