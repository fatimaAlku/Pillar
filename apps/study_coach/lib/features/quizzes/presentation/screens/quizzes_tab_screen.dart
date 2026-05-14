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
    } else if (_linkTopicIds.isNotEmpty) {
      topicsForAi = _linkTopicIds
          .map((id) => _linkTopicTitles[id]?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (topicsForAi.isEmpty) {
        _showMessage(strings.quizTopicsPickAtLeastOne);
        return;
      }
    } else if (typed.isNotEmpty) {
      // Course has a topic bank, but the user typed topics instead of using
      // chips — still valid for generation (weak-topic IDs stay empty).
      topicsForAi = typed;
    } else {
      _showMessage(strings.quizTopicsPickAtLeastOne);
      return;
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const _QuizTabHero(),
        const SizedBox(height: 18),
        _QuizGradientFrame(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      labelText: strings.notesOptional,
                      hintText: strings.notesOptionalHint,
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
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.primary,
                              colorScheme.tertiary,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            strings.difficulty,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 6,
                      ),
                      textStyle: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    segments: [
                      ButtonSegment<String>(
                        value: 'easy',
                        label: Text(
                          strings.easy,
                          maxLines: 1,
                          softWrap: false,
                        ),
                        icon: const Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                          size: 16,
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'medium',
                        label: Text(
                          strings.medium,
                          maxLines: 1,
                          softWrap: false,
                        ),
                        icon: const Icon(Icons.balance_outlined, size: 16),
                      ),
                      ButtonSegment<String>(
                        value: 'hard',
                        label: Text(
                          strings.hard,
                          maxLines: 1,
                          softWrap: false,
                        ),
                        icon: const Icon(
                          Icons.local_fire_department_outlined,
                          size: 16,
                        ),
                      ),
                    ],
                    selected: {_difficulty},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      setState(() => _difficulty = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 22),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.primary,
                              colorScheme.tertiary,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            strings.numberOfQuestions,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.55),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                ),
                const SizedBox(height: 6),
                // Numeric scales read low→high left→right; keep LTR so labels match
                // the slider track in Arabic (RTL) layouts.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
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
                ),
                const SizedBox(height: 22),
                _QuizPrimaryCta(
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
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    isGenerating ? strings.generating : strings.startQuiz,
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
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 22,
                  color: colorScheme.primary.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.quizNoCoursesAddFirst,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

class _QuizGradientFrame extends StatelessWidget {
  const _QuizGradientFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.tertiary.withValues(alpha: 0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22.5),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

class _QuizTabHero extends StatelessWidget {
  const _QuizTabHero();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onCont = colorScheme.onPrimaryContainer;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      Color.lerp(
                            colorScheme.tertiaryContainer,
                            colorScheme.primaryContainer,
                            0.35,
                          )!
                          .withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -38,
              child: Icon(
                Icons.quiz_rounded,
                size: 104,
                color: colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              left: -22,
              bottom: -26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.tertiary.withValues(alpha: 0.12),
                ),
                child: const SizedBox.square(dimension: 82),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.generateQuiz,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.15,
                            color: onCont,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(
                                alpha: 0.58,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colorScheme.outline
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              child: Text(
                                strings.generateQuizDescription,
                                textAlign: TextAlign.start,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: onCont.withValues(alpha: 0.92),
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.38),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.onPrimary.withValues(alpha: 0.14),
                          ),
                        ),
                        Icon(
                          Icons.quiz_rounded,
                          size: 34,
                          color: colorScheme.onPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizPrimaryCta extends StatelessWidget {
  const _QuizPrimaryCta({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  Color.lerp(
                        colorScheme.primary,
                        colorScheme.tertiary,
                        0.75,
                      )!,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(color: onPrimary, size: 26),
                    child: icon,
                  ),
                  const SizedBox(width: 10),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    child: label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
