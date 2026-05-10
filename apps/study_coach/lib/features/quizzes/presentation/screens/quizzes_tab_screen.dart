import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/notes/notes_file_text_extractor.dart';
import '../../../../core/state/app_providers.dart';
import '../../../subjects/domain/entities/topic_item.dart';
import '../../../subjects/presentation/controllers/subject_topics_providers.dart';
import '../../domain/entities/quiz_submission_result.dart';
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
  final _notesScrollController = ScrollController();
  final _notesFocusNode = FocusNode();
  int _questionCount = 10;
  String _difficulty = 'medium';
  String _quizEmphasis = 'balanced';
  bool _isImportingNotes = false;

  /// Required link to My courses — persisted on quiz history for weak-topic context.
  String? _linkSubjectId;
  String? _linkSubjectTitle;
  final List<String> _linkTopicIds = [];
  final Map<String, String> _linkTopicTitles = {};

  static const int _minQuestions = 5;
  static const int _maxQuestions = 15;

  void _resetQuizForm() {
    setState(() {
      _topicsController.clear();
      _notesController.clear();
      if (_notesScrollController.hasClients) {
        _notesScrollController.jumpTo(0);
      }
      _difficulty = 'medium';
      _questionCount = 10;
      _quizEmphasis = 'balanced';
      _linkSubjectId = null;
      _linkSubjectTitle = null;
      _linkTopicIds.clear();
      _linkTopicTitles.clear();
    });
    ref.read(quizRunnerControllerProvider.notifier).resetSession();
  }

  Future<void> _startQuiz(AppStrings strings) async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      _showMessage(strings.notesRequiredForQuiz);
      return;
    }

    final authUser = ref.read(currentAuthUserProvider).valueOrNull;
    final quizUid = authUser?.uid.trim();
    if (quizUid == null || quizUid.isEmpty) return;

    final subjects = ref.read(subjectsStreamProvider(quizUid)).valueOrNull ?? [];
    if (subjects.isEmpty) {
      _showMessage(strings.quizNoCoursesAddFirst);
      return;
    }

    final sid = _linkSubjectId?.trim();
    if (sid == null || sid.isEmpty) {
      _showMessage(strings.quizCourseRequired);
      return;
    }

    List<TopicItem> courseTopics;
    try {
      courseTopics = await ref.read(
        subjectTopicsStreamProvider(SubjectTopicsKey(quizUid, sid)).future,
      );
    } catch (_) {
      courseTopics = const [];
    }

    final typed = _topicsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    late final List<String> topicsForAi;
    if (courseTopics.isEmpty) {
      if (typed.isEmpty) {
        _showMessage(strings.quizTopicsFieldRequiredForCourse);
        return;
      }
      topicsForAi = typed;
    } else {
      if (_linkTopicIds.isEmpty) {
        _showMessage(strings.quizTopicsPickAtLeastOne);
        return;
      }
      topicsForAi = _linkTopicIds
          .map((id) => _linkTopicTitles[id]?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (topicsForAi.isEmpty) {
        _showMessage(strings.quizTopicsPickAtLeastOne);
        return;
      }
    }

    final linkContext = QuizLinkContext(
      subjectId: sid,
      subjectTitle: _linkSubjectTitle?.trim() ?? '',
      linkedTopicIds: List<String>.from(_linkTopicIds),
      linkedTopicTitles: _linkTopicIds
          .map((id) => _linkTopicTitles[id]?.trim() ?? '')
          .toList(growable: false),
    );

    await ref.read(quizRunnerControllerProvider.notifier).generateQuiz(
          topics: topicsForAi,
          notesText: notes,
          difficulty: _difficulty,
          numberOfQuestions: _questionCount,
          quizEmphasis: _quizEmphasis,
          linkContext: linkContext,
        );

    if (!mounted) return;
    final nextState = ref.read(quizRunnerControllerProvider);
    if (nextState is QuizRunnerInProgress || nextState is QuizRunnerSubmitted) {
      final shouldReset = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const QuizRunnerScreen(),
        ),
      );
      if (!mounted) return;
      if (shouldReset == true) {
        _resetQuizForm();
      }
      return;
    }

    if (nextState is QuizRunnerError) {
      _showMessage(nextState.message);
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(message),
        ),
      );
  }

  @override
  void dispose() {
    _topicsController.dispose();
    _notesController.dispose();
    _notesScrollController.dispose();
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
      _showMessage(strings.notesImported);
      setState(() {});
    } on NotesImportException catch (e) {
      if (!mounted) return;
      final msg = switch (e.failure) {
        NotesImportFailure.unsupportedType => strings.unsupportedNotesFile,
        NotesImportFailure.unreadableText => strings.unreadableNotesFile,
        NotesImportFailure.unknown => strings.couldNotImportNotes,
      };
      _showMessage(msg);
    } catch (_) {
      if (!mounted) return;
      _showMessage(strings.couldNotImportNotes);
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
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final quizUid = authUser?.uid.trim();
    final hasAnyCourse = quizUid != null &&
        quizUid.isNotEmpty &&
        (ref.watch(subjectsStreamProvider(quizUid)).valueOrNull?.isNotEmpty ??
            false);

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
                _buildQuizCourseLinkSection(
                  strings,
                  theme,
                  colorScheme,
                  isGenerating,
                ),
                const SizedBox(height: 14),
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
                Scrollbar(
                  controller: _notesScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(8),
                  child: TextField(
                    controller: _notesController,
                    scrollController: _notesScrollController,
                    focusNode: _notesFocusNode,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      labelText: strings.notesRequired,
                      hintText: strings.notesHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                _buildNoteActions(strings),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('emphasis_$_quizEmphasis'),
                  initialValue: _quizEmphasis,
                  decoration: InputDecoration(
                    labelText: strings.quizQuestionStyle,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'balanced',
                      child: Text(strings.quizStyleBalanced),
                    ),
                    DropdownMenuItem(
                      value: 'definitions',
                      child: Text(strings.quizStyleDefinitions),
                    ),
                    DropdownMenuItem(
                      value: 'application',
                      child: Text(strings.quizStyleApplication),
                    ),
                    DropdownMenuItem(
                      value: 'exam',
                      child: Text(strings.quizStyleExam),
                    ),
                  ],
                  onChanged: isGenerating
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _quizEmphasis = v);
                        },
                ),
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
                  onPressed: isGenerating || !hasAnyCourse
                      ? null
                      : () => _startQuiz(strings),
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

  Widget _buildQuizCourseLinkSection(
    AppStrings strings,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isGenerating,
  ) {
    final auth = ref.watch(currentAuthUserProvider).valueOrNull;
    final uid = auth?.uid.trim();
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    final subjectsAsync = ref.watch(subjectsStreamProvider(uid));

    return subjectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 14),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (subjects) {
        if (subjects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              strings.quizNoCoursesAddFirst,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.quizLinkCourseRequiredTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.quizLinkCourseRequiredHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>('quiz_link_subject_${_linkSubjectId ?? 'none'}'),
                initialValue: _linkSubjectId,
                decoration: InputDecoration(
                  labelText: strings.courseName,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.quizSelectCoursePlaceholder),
                  ),
                  ...subjects.map(
                    (s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(
                        s.name.trim().isEmpty ? strings.unnamedCourse : s.name,
                      ),
                    ),
                  ),
                ],
                onChanged: isGenerating
                    ? null
                    : (value) {
                        setState(() {
                          _linkSubjectId = value;
                          _linkSubjectTitle = null;
                          _linkTopicIds.clear();
                          _linkTopicTitles.clear();
                          if (value != null && value.isNotEmpty) {
                            for (final s in subjects) {
                              if (s.id == value) {
                                final n = s.name.trim();
                                _linkSubjectTitle =
                                    n.isEmpty ? strings.unnamedCourse : n;
                                break;
                              }
                            }
                          }
                        });
                      },
              ),
              if (_linkSubjectId != null && _linkSubjectId!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ref
                    .watch(
                      subjectTopicsStreamProvider(
                        SubjectTopicsKey(uid, _linkSubjectId!),
                      ),
                    )
                    .when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (topics) {
                        if (topics.isEmpty) {
                          return Text(
                            strings.quizEnterTopicsWhenCourseHasNone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.topicTitleLabel,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.quizTopicsPickAtLeastOne,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: topics.map((t) {
                                final selected = _linkTopicIds.contains(t.id);
                                return FilterChip(
                                  label: Text(t.title),
                                  selected: selected,
                                  onSelected: isGenerating
                                      ? null
                                      : (sel) {
                                          setState(() {
                                            if (sel) {
                                              if (!_linkTopicIds.contains(t.id)) {
                                                _linkTopicIds.add(t.id);
                                              }
                                              _linkTopicTitles[t.id] = t.title;
                                            } else {
                                              _linkTopicIds.remove(t.id);
                                              _linkTopicTitles.remove(t.id);
                                            }
                                          });
                                        },
                                );
                              }).toList(),
                            ),
                            if (_linkTopicIds.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton.icon(
                                    onPressed: isGenerating
                                        ? null
                                        : () {
                                            final parts = _linkTopicIds
                                                .map(
                                                  (id) =>
                                                      _linkTopicTitles[id]
                                                          ?.trim() ??
                                                      '',
                                                )
                                                .where((e) => e.isNotEmpty)
                                                .toList();
                                            if (parts.isEmpty) return;
                                            _topicsController.text =
                                                parts.join(', ');
                                            setState(() {});
                                          },
                                    icon: const Icon(
                                      Icons.topic_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      strings.quizFillTopicsFromSelection,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}
