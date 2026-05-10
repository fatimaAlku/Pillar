import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/pillar_theme.dart';
import '../quiz_report_exporter.dart';
import '../../domain/entities/quiz_question.dart';
import '../../domain/entities/quiz_submission_result.dart';
import '../controllers/quiz_controller.dart';

class QuizRunnerScreen extends ConsumerStatefulWidget {
  const QuizRunnerScreen({super.key});

  @override
  ConsumerState<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends ConsumerState<QuizRunnerScreen> {
  final _reportExporter = const QuizReportExporter();
  bool _isExporting = false;
  static const _quizReportShareChannel = MethodChannel('pillar.quiz_report_share');

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final quizState = ref.watch(quizRunnerControllerProvider);
    final submittedState =
        quizState is QuizRunnerSubmitted ? quizState : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.quiz),
        actions: [
          if (submittedState != null)
            IconButton(
              tooltip: strings.downloadQuizReport,
              onPressed: _isExporting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() {
                        _isExporting = true;
                      });
                      final result = submittedState.result;
                      String filePath = '';
                      try {
                        final bytes = await _reportExporter
                            .buildQuizReviewReportPdfBytes(
                          result: result,
                          strings: strings,
                          generatedAt: DateTime.now(),
                        );

                        final dir = await getTemporaryDirectory();
                        filePath =
                            '${dir.path}/quiz_review_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

                        final file = File(filePath);
                        await file.writeAsBytes(bytes, flush: true);

                        if (!await file.exists() || await file.length() == 0) {
                          throw Exception('Quiz report PDF file not created');
                        }
                      } catch (e, st) {
                        if (!mounted) return;
                        debugPrint('Quiz report export failed: $e');
                        debugPrintStack(stackTrace: st);
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text('${strings.couldNotExportQuizReport}\n$e'),
                          ),
                        );
                        return;
                      }

                      try {
                        if (Platform.isIOS) {
                          await _quizReportShareChannel.invokeMethod(
                            'sharePdf',
                            {'filePath': filePath},
                          );
                        } else {
                          await SharePlus.instance.share(
                            ShareParams(
                              files: [XFile(filePath)],
                              subject: strings.quizReport,
                              text: strings.quizReport,
                            ),
                          );
                        }
                      } catch (e, st) {
                        if (!mounted) return;
                        debugPrint('Quiz report share failed: $e');
                        debugPrintStack(stackTrace: st);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${strings.couldNotExportQuizReport}\n$e',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isExporting = false;
                          });
                        }
                      }
                    },
              icon: Image.asset(
                'assets/icons/quiz_report_icon.png',
                width: 22,
                height: 22,
              ),
            ),
        ],
      ),
      body: switch (quizState) {
        QuizRunnerIdle() => const _QuizIdleView(),
        QuizRunnerLoading() => const _QuizLoadingView(),
        QuizRunnerError() => _QuizErrorView(message: quizState.message),
        QuizRunnerInProgress() => _QuizInProgressView(state: quizState),
        QuizRunnerSubmitted() => _QuizSubmittedView(result: quizState.result),
      },
    );
  }
}

class _QuizIdleView extends StatelessWidget {
  const _QuizIdleView();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(strings.noQuizLoaded),
      ),
    );
  }
}

class _QuizLoadingView extends StatelessWidget {
  const _QuizLoadingView();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(strings.generatingQuizWithAi),
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
    final strings = AppStrings.of(context);
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
              label: Text(strings.retryGeneration),
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
    final strings = AppStrings.of(context);
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
                    strings.questionCounter(
                        state.questionNumber, state.totalCount),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  strings.questionOf(state.questionNumber, state.totalCount),
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
                    label: Text(strings.back),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (state.isLastQuestion) {
                        ref
                            .read(quizRunnerControllerProvider.notifier)
                            .submit();
                      } else {
                        ref.read(quizRunnerControllerProvider.notifier).next();
                      }
                    },
                    icon: Icon(
                      state.isLastQuestion ? Icons.check : Icons.chevron_right,
                    ),
                    label: Text(
                        state.isLastQuestion ? strings.submit : strings.next),
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
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
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
    final strings = AppStrings.of(context);
    final result = this.result;
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
                  Text(strings.score,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '${result.correctCount}/${result.totalCount} ($percent%)',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (result.linkContext != null &&
                      result.linkContext!.hasSubject) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${strings.quizLinkedScopeLabel}: ${result.linkContext!.displayLine}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => ref
                          .read(quizRunnerControllerProvider.notifier)
                          .restart(),
                      icon: const Icon(Icons.refresh),
                      label: Text(strings.retake),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(title: strings.weakTopics),
          const SizedBox(height: 8),
          if (result.weakTopics.isEmpty)
            Text(
              strings.noWeakTopics,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...result.weakTopics.map(
              (t) => Card(
                child: ListTile(
                  leading: Icon(Icons.trending_down, color: colorScheme.error),
                  title: Text(t.topicTitle),
                  subtitle: Text(strings.incorrectCount(t.incorrectCount)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _SectionTitle(title: strings.review),
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
                          color: isCorrect
                              ? PillarColors.success
                              : colorScheme.error,
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
                      strings.yourAnswer(
                        selected == null
                            ? strings.unanswered
                            : q.options[selected],
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.correctAnswer(q.options[q.correctIndex]),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isCorrect
                                ? PillarColors.success
                                : colorScheme.primary,
                          ),
                    ),
                    if (q.explanation != null &&
                        q.explanation!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          strings.explanation(q.explanation!),
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
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.backToQuizzes),
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
