import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/quiz_controller.dart';
import 'quiz_runner_screen.dart';

class QuizzesTabScreen extends ConsumerStatefulWidget {
  const QuizzesTabScreen({super.key});

  @override
  ConsumerState<QuizzesTabScreen> createState() => _QuizzesTabScreenState();
}

class _QuizzesTabScreenState extends ConsumerState<QuizzesTabScreen> {
  final _topicsController = TextEditingController();
  final _notesController = TextEditingController();
  int _questionCount = 10;
  String _difficulty = 'medium';

  @override
  void dispose() {
    _topicsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.16),
                    ),
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Build AI-powered quizzes and target weak topics faster.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate AI Quiz',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use topics and/or notes to generate a quiz, then review weak topics.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _topicsController,
                  decoration: const InputDecoration(
                    labelText: 'Topics (comma-separated)',
                    hintText: 'e.g. Trees, Graphs, Hashing',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Paste notes for quiz generation context',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _difficulty = value);
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Number of questions',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          min: 5,
                          max: 20,
                          divisions: 15,
                          value: _questionCount.toDouble(),
                          label: '$_questionCount',
                          onChanged: (v) =>
                              setState(() => _questionCount = v.round()),
                        ),
                      ),
                      Text('$_questionCount'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final topics = _topicsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      final notes = _notesController.text.trim();

                      await ref.read(quizRunnerControllerProvider.notifier).generateQuiz(
                            topics: topics,
                            notesText: notes.isEmpty ? null : notes,
                            difficulty: _difficulty,
                            numberOfQuestions: _questionCount,
                          );

                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const QuizRunnerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start quiz'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
