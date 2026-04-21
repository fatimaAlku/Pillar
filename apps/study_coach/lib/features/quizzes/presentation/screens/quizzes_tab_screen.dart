import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/notes/notes_file_text_extractor.dart';
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
  final _notesFocusNode = FocusNode();
  int _questionCount = 10;
  String _difficulty = 'medium';
  bool _isImportingNotes = false;

  static const int _minQuestions = 5;
  static const int _maxQuestions = 15;

  @override
  void dispose() {
    _topicsController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _insertImportedNotes(String imported) {
    final value = _notesController.value;
    final text = value.text;
    final sel = value.selection;
    int start;
    int end;
    if (sel.isValid) {
      start = sel.start.clamp(0, text.length);
      end = sel.end.clamp(0, text.length);
      if (end < start) {
        end = start;
      }
    } else {
      start = end = text.length;
    }
    final newText = text.replaceRange(start, end, imported);
    final offset = start + imported.length;
    _notesController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  Future<void> _importNotesFromFile() async {
    if (_isImportingNotes) return;
    final strings = AppStrings.of(context);
    setState(() => _isImportingNotes = true);
    try {
      final importedText = await NotesFileTextExtractor.pickAndExtractText();
      if (!mounted || importedText == null) return;
      _notesFocusNode.requestFocus();
      _insertImportedNotes(importedText);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.notesImported)),
      );
      setState(() {});
    } on NotesImportException catch (e) {
      if (!mounted) return;
      final msg = switch (e.failure) {
        NotesImportFailure.unsupportedType => strings.unsupportedNotesFile,
        NotesImportFailure.unreadableText => strings.unreadableNotesFile,
        NotesImportFailure.unknown => strings.couldNotImportNotes,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotImportNotes)),
      );
    } finally {
      if (mounted) setState(() => _isImportingNotes = false);
    }
  }

  Widget _buildNoteActions(AppStrings strings) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 6,
        children: [
          TextButton.icon(
            onPressed: _isImportingNotes ? null : _importNotesFromFile,
            icon: _isImportingNotes
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded, size: 20),
            label: Text(
              _isImportingNotes
                  ? strings.importingNotes
                  : strings.uploadNotesFile,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quizState = ref.watch(quizRunnerControllerProvider);
    final isGenerating = quizState is QuizRunnerLoading;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.85),
            ),
          ),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.quiz_rounded,
                          color: colorScheme.primary,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        strings.generateQuizDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _topicsController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.topicsCommaSeparated,
                    hintText: strings.topicsHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: 5,
                  minLines: 4,
                  decoration: InputDecoration(
                    alignLabelWithHint: true,
                    labelText: strings.notesRequired,
                    hintText: strings.notesHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                _buildNoteActions(strings),
                const SizedBox(height: 18),
                Text(
                  strings.difficulty,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'easy',
                      label: Text(strings.easy),
                      icon: const Icon(Icons.sentiment_satisfied_alt_outlined,
                          size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'medium',
                      label: Text(strings.medium),
                      icon: const Icon(Icons.balance_outlined, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'hard',
                      label: Text(strings.hard),
                      icon: const Icon(Icons.local_fire_department_outlined,
                          size: 18),
                    ),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    setState(() => _difficulty = selection.first);
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.numberOfQuestions,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_questionCount',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$_minQuestions',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        min: _minQuestions.toDouble(),
                        max: _maxQuestions.toDouble(),
                        divisions: _maxQuestions - _minQuestions,
                        value: _questionCount
                            .clamp(_minQuestions, _maxQuestions)
                            .toDouble(),
                        label: '$_questionCount',
                        onChanged: isGenerating
                            ? null
                            : (v) => setState(
                                  () => _questionCount = v
                                      .round()
                                      .clamp(_minQuestions, _maxQuestions),
                                ),
                      ),
                    ),
                    Text(
                      '$_maxQuestions',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: isGenerating
                      ? null
                      : () async {
                          final topics = _topicsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          final notes = _notesController.text.trim();
                          if (notes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.notesRequiredForQuiz),
                              ),
                            );
                            return;
                          }

                          await ref
                              .read(quizRunnerControllerProvider.notifier)
                              .generateQuiz(
                                topics: topics,
                                notesText: notes,
                                difficulty: _difficulty,
                                numberOfQuestions: _questionCount,
                              );

                          if (!context.mounted) return;
                          final nextState =
                              ref.read(quizRunnerControllerProvider);
                          if (nextState is QuizRunnerInProgress ||
                              nextState is QuizRunnerSubmitted) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const QuizRunnerScreen(),
                              ),
                            );
                            return;
                          }

                          if (nextState is QuizRunnerError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(nextState.message)),
                            );
                          }
                        },
                  icon: isGenerating
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          Icons.play_arrow_rounded,
                          size: 26,
                          color: colorScheme.onPrimary,
                        ),
                  label: Text(
                    isGenerating ? strings.generating : strings.startQuiz,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimary,
                    ),
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
