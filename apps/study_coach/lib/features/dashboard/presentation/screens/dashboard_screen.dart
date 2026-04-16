import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../profile/presentation/screens/profile_tab_screen.dart';
import '../../../quizzes/presentation/screens/quizzes_tab_screen.dart';
import '../../../roadmap/presentation/screens/roadmap_tab_screen.dart';
import '../../../study_plan/presentation/screens/study_plan_tab_screen.dart';
import '../widgets/home_dashboard_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final pages = <Widget>[
      const HomeDashboardView(),
      const StudyPlanTabScreen(),
      const QuizzesTabScreen(),
      const RoadmapTabScreen(),
      const ProfileTabScreen(),
    ];

    return Scaffold(
      appBar: AppBar(toolbarHeight: 36),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.32),
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0, 0.32, 1],
          ),
        ),
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          iconSize: 20,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: strings.navHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.event_note_outlined),
              activeIcon: const Icon(Icons.event_note),
              label: strings.navPlan,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.quiz_outlined),
              activeIcon: const Icon(Icons.quiz),
              label: strings.navQuiz,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.route_outlined),
              activeIcon: const Icon(Icons.route),
              label: strings.navRoadmap,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: strings.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
