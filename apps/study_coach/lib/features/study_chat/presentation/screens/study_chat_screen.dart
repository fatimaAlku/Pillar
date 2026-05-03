import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../../profile/presentation/screens/profile_editor_screen.dart';
import '../../../roadmap/domain/major_catalog.dart';
import '../controllers/study_chat_controller.dart';

class StudyChatScreen extends ConsumerStatefulWidget {
  const StudyChatScreen({super.key});

  @override
  ConsumerState<StudyChatScreen> createState() => _StudyChatScreenState();
}

class _StudyChatScreenState extends ConsumerState<StudyChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _onSend({
    required String languageCode,
    required String? majorId,
  }) async {
    final strings = AppStrings.of(context);
    final text = _textController.text;
    final err =
        await ref.read(studyChatControllerProvider.notifier).sendUserMessage(
              text: text,
              languageCode: languageCode,
              majorId: majorId,
            );
    if (!mounted) return;
    if (err == 'no_major') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.studyChatNoMajorTitle)),
      );
      return;
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final uid = authUser?.uid;

    final chatState = ref.watch(studyChatControllerProvider);
    ref.listen<StudyChatState>(studyChatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.studyChatTitle),
        actions: [
          if (chatState.messages.isNotEmpty)
            TextButton(
              onPressed: chatState.isSending
                  ? null
                  : () => ref
                      .read(studyChatControllerProvider.notifier)
                      .clearConversation(),
              child: Text(strings.studyChatClear),
            ),
        ],
      ),
      body: uid == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  strings.signInToSeeStudyPlan,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          : ref.watch(userProfileStreamProvider(uid)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (profile) {
                  final majorId = profile?.majorId;
                  final majorTitle = majorTitleFromId(majorId);
                  final hasMajor = majorTitle.isNotEmpty;

                  if (!hasMajor) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 56,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            strings.studyChatNoMajorTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            strings.studyChatNoMajorBody,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ProfileEditorScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_outline_rounded),
                            label: Text(strings.studyChatOpenProfile),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${strings.studyChatMajorLabel}: $majorTitle',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Text(
                          strings.studyChatDisclaimer,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: chatState.messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    strings.studyChatEmptyState,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: chatState.messages.length,
                                itemBuilder: (context, index) {
                                  final m = chatState.messages[index];
                                  return _ChatBubble(
                                    isUser: m.isUser,
                                    text: m.text,
                                  );
                                },
                              ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: strings.studyChatInputHint,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                  ),
                                  onSubmitted: (_) {
                                    if (chatState.isSending) return;
                                    unawaited(_onSend(
                                      languageCode: locale,
                                      majorId: majorId,
                                    ));
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: chatState.isSending
                                    ? null
                                    : () => unawaited(_onSend(
                                          languageCode: locale,
                                          majorId: majorId,
                                        )),
                                icon: chatState.isSending
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                                tooltip: strings.studyChatSend,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = isUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final fg = isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.86,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SelectableText(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
