import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/quiz_question.dart';
import '../../domain/entities/quiz_submission_result.dart';
import '../controllers/quiz_controller.dart';

class QuizRunnerScreen extends ConsumerWidget {
  const QuizRunnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizRunnerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: switch (state) {
        QuizRunnerIdle() => const _QuizIdleView(),
        QuizRunnerLoading() => const _QuizLoadingView(),
        QuizRunnerError() => _QuizErrorView(message: state.message),
        QuizRunnerInProgress() => _QuizInProgressView(state: state),
        QuizRunnerSubmitted() => _QuizSubmittedView(result: state.result),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _QuizIdleView extends StatelessWidget {
  const _QuizIdleView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No quiz loaded yet. Generate one from the Quiz tab.'),
      ),
    );
  }
}

class _QuizLoadingView extends StatelessWidget {
  const _QuizLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Generating quiz with AI...'),
        ],
      ),
    );
  }
}

class _QuizErrorView extends ConsumerWidget {
  const _QuizErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref
                  .read(quizRunnerControllerProvider.notifier)
                  .retryLastGeneration(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry generation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizInProgressView extends ConsumerWidget {
  const _QuizInProgressView({required this.state});

  final QuizRunnerInProgress state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = state.currentQuestion;
    final selected = state.selectedFor(q.id);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${state.questionNumber}/${state.totalCount}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${state.questionNumber} of ${state.totalCount}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: state.totalCount == 0
                  ? 0
                  : state.questionNumber / state.totalCount,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _QuestionCard(question: q),
                const SizedBox(height: 12),
                ...List.generate(
                  q.options.length,
                  (index) => _OptionTile(
                    label: q.options[index],
                    isSelected: selected == index,
                    onTap: () => ref
                        .read(quizRunnerControllerProvider.notifier)
                        .selectOption(questionId: q.id, optionIndex: index),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isFirstQuestion
                        ? null
                        : () => ref
                            .read(quizRunnerControllerProvider.notifier)
                            .previous(),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (state.isLastQuestion) {
                        ref.read(quizRunnerControllerProvider.notifier).submit();
                      } else {
                        ref.read(quizRunnerControllerProvider.notifier).next();
                      }
                    },
                    icon: Icon(
                      state.isLastQuestion ? Icons.check : Icons.chevron_right,
                    ),
                    label: Text(state.isLastQuestion ? 'Submit' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.topicTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : colorScheme.surface,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizSubmittedView extends ConsumerWidget {
  const _QuizSubmittedView({required this.result});

  final QuizSubmissionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = (result.scoreFraction * 100).round();
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Score', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '${result.correctCount}/${result.totalCount} ($percent%)',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => ref
                          .read(quizRunnerControllerProvider.notifier)
                          .restart(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(title: 'Weak topics'),
          const SizedBox(height: 8),
          if (result.weakTopics.isEmpty)
            Text(
              'No weak topics detected — great job.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...result.weakTopics.map(
              (t) => Card(
                child: ListTile(
                  leading: Icon(Icons.trending_down, color: colorScheme.error),
                  title: Text(t.topicTitle),
                  subtitle: Text('${t.incorrectCount} incorrect'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _SectionTitle(title: 'Review'),
          const SizedBox(height: 8),
          ...result.questions.map((q) {
            final selected = result.selectedByQuestionId[q.id];
            final isCorrect = selected != null && selected == q.correctIndex;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.prompt,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your answer: ${selected == null ? 'Unanswered' : q.options[selected]}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correct answer: ${q.options[q.correctIndex]}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                isCorrect ? Colors.green : colorScheme.primary,
                          ),
                    ),
                    if (q.explanation != null && q.explanation!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Explanation: ${q.explanation}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back to quizzes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

