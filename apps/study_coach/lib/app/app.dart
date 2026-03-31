import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/app_providers.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import 'splash_screen.dart';

class StudyCoachApp extends StatelessWidget {
  const StudyCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pillar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(currentAuthUserProvider);
    return authUser.when(
      data: (user) => user == null ? const AuthScreen() : const DashboardScreen(),
      loading: () => const SplashScreen(),
      error: (_, __) => const AuthScreen(),
    );
  }
}
