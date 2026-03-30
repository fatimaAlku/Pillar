import 'package:flutter/material.dart';

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
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pillar AI Study Coach')),
      body: const Center(
        child: Text(
          'Starter scaffold ready.\nNext: subjects, plans, quizzes, progress.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
