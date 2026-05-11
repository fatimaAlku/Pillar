import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../study_plan/domain/entities/study_session.dart';
import '../../../study_plan/presentation/controllers/study_plan_firestore_providers.dart';

const _focusCompletionExitDelay = Duration(milliseconds: 700);

final _focusSessionDraftProvider =
    StateProvider.family<_FocusSessionDraft?, String>((ref, key) => null);

class _FocusSessionDraft {
  const _FocusSessionDraft({
    required this.remainingSeconds,
    required this.isRunning,
  });

  final int remainingSeconds;
  final bool isRunning;
}

String _focusSessionDraftKey({
  required String uid,
  required StudySession session,
}) =>
    '$uid/${session.planId}/${session.id}';

class FocusSessionScreen extends ConsumerStatefulWidget {
  const FocusSessionScreen({
    super.key,
    required this.uid,
    required this.session,
    required this.topicTitle,
  });

  final String uid;
  final StudySession session;
  final String topicTitle;

  @override
  ConsumerState<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends ConsumerState<FocusSessionScreen> {
  Timer? _timer;
  late final String _draftKey;
  late int _remainingSeconds;
  bool _isRunning = true;
  bool _isSaving = false;
  bool _completed = false;

  int get _totalSeconds =>
      Duration(minutes: widget.session.durationMin.clamp(1, 240)).inSeconds;

  @override
  void initState() {
    super.initState();
    _draftKey = _focusSessionDraftKey(
      uid: widget.uid,
      session: widget.session,
    );
    final draft = ref.read(_focusSessionDraftProvider(_draftKey));
    _remainingSeconds =
        (draft?.remainingSeconds ?? _totalSeconds).clamp(0, _totalSeconds);
    _isRunning = _remainingSeconds > 0 && (draft?.isRunning ?? true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning || _isSaving || _completed) return;
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
        _saveDraft();
        unawaited(_completeSession());
        return;
      }
      setState(() => _remainingSeconds -= 1);
      _saveDraft();
    });
  }

  void _toggleRunning() {
    setState(() => _isRunning = !_isRunning);
    _saveDraft();
  }

  void _saveDraft() {
    if (_completed) return;
    ref.read(_focusSessionDraftProvider(_draftKey).notifier).state =
        _FocusSessionDraft(
      remainingSeconds: _remainingSeconds,
      isRunning: _isRunning,
    );
  }

  Future<void> _completeSession() async {
    if (_isSaving || _completed) return;
    final strings = AppStrings.of(context);
    setState(() {
      _isSaving = true;
      _isRunning = false;
    });
    _saveDraft();
    try {
      await ref.read(studySessionsRepositoryProvider).setSessionCompleted(
            uid: widget.uid,
            planId: widget.session.planId,
            sessionId: widget.session.id,
            completed: true,
          );
      if (!mounted) return;
      setState(() {
        _completed = true;
        _isSaving = false;
      });
      ref.read(_focusSessionDraftProvider(_draftKey).notifier).state = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.focusSessionCompleted)),
      );
      await Future<void>.delayed(_focusCompletionExitDelay);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _saveDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotUpdateSession)),
      );
    }
  }

  String _formatRemaining() {
    final duration = Duration(seconds: _remainingSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _totalSeconds <= 0
        ? 1.0
        : 1 - (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.focusModeTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 44,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.topicTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        strings.focusModeSubtitle(
                          widget.session.durationMin,
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatRemaining(),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _completed
                          ? strings.focusSessionCompleted
                          : _isRunning
                              ? strings.focusSessionRunning
                              : strings.focusSessionPaused,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _isSaving || _completed ? null : _toggleRunning,
                icon: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(
                  _isRunning
                      ? strings.pauseFocusSession
                      : strings.resumeFocusSession,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving || _completed ? null : _completeSession,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(strings.finishFocusSession),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
