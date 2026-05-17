import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'demo_data_seeder.dart';

final demoDataSeederProvider = Provider<DemoDataSeeder>((ref) {
  return DemoDataSeeder(ref.watch(firestoreProvider));
});
