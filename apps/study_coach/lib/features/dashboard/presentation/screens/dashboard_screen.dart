import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../../quizzes/presentation/controllers/quiz_controller.dart';
import '../../../recommendations/presentation/controllers/recommendations_controller.dart';
import '../../../study_plan/presentation/controllers/study_plan_controller.dart';
import '../../../subjects/presentation/controllers/subjects_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final subjectsState = ref.watch(subjectsControllerProvider);
    final planState = ref.watch(studyPlanControllerProvider);
    final quizState = ref.watch(quizControllerProvider);
    final progressState = ref.watch(progressControllerProvider);
    final recommendationsState = ref.watch(recommendationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pillar Dashboard'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(authFormControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusTile(title: 'Auth', status: authState.status),
          _StatusTile(title: 'Subjects', status: subjectsState.status),
          _StatusTile(title: 'Study Plan', status: planState.status),
          _StatusTile(title: 'Quiz', status: quizState.status),
          _StatusTile(title: 'Progress', status: progressState.status),
          _StatusTile(
            title: 'Recommendations',
            status: recommendationsState.status,
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(status),
      ),
    );
  }
}
