import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../../roadmap/domain/major_catalog.dart';
import '../../../subjects/domain/entities/subject.dart';
import '../../../subjects/domain/entities/topic_item.dart';
import '../../../subjects/presentation/controllers/subject_topics_providers.dart';
import '../../data/services/study_chat_ai_service.dart';
import '../../data/study_chat_preflight.dart';
import '../../domain/entities/study_chat_turn.dart';

class StudyChatUiMessage {
  const StudyChatUiMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

class StudyChatState {
  const StudyChatState({
    this.messages = const [],
    this.isSending = false,
  });

  final List<StudyChatUiMessage> messages;
  final bool isSending;

  StudyChatState copyWith({
    List<StudyChatUiMessage>? messages,
    bool? isSending,
  }) {
    return StudyChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }
}

final studyChatControllerProvider =
    StateNotifierProvider.autoDispose<StudyChatController, StudyChatState>(
  (ref) => StudyChatController(ref),
);

class StudyChatController extends StateNotifier<StudyChatState> {
  StudyChatController(this._ref) : super(const StudyChatState());

  final Ref _ref;

  /// Returns `null` on success, or an error token for the UI (e.g. `no_major`, `no_courses`).
  Future<String?> sendUserMessage({
    required String text,
    required String languageCode,
    required String? majorId,
    required String? uid,
    required String refusalOffTopic,
    required String refusalBlockedInjection,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final majorTitle = majorTitleFromId(majorId);
    if (majorTitle.isEmpty) {
      return 'no_major';
    }

    final quizUid = uid?.trim();
    if (quizUid == null || quizUid.isEmpty) {
      return 'no_uid';
    }

    List<Subject> subjects;
    try {
      subjects = await _ref.read(subjectsStreamProvider(quizUid).future);
    } catch (_) {
      subjects = [];
    }
    if (subjects.isEmpty) {
      return 'no_courses';
    }

    final allowedCourses = subjects
        .map((s) {
          final name = s.name.trim();
          return name.isEmpty ? 'Unnamed course' : name;
        })
        .toList(growable: false);

    final topicFutures = subjects.map((s) async {
      try {
        return await _ref.read(
          subjectTopicsStreamProvider(
            SubjectTopicsKey(quizUid, s.id),
          ).future,
        );
      } catch (_) {
        return <TopicItem>[];
      }
    });
    final topicLists = await Future.wait(topicFutures);
    final topicSet = <String>{};
    for (final list in topicLists) {
      for (final t in list) {
        final title = t.title.trim();
        if (title.isNotEmpty) topicSet.add(title);
      }
    }
    final allowedTopics = topicSet.toList()..sort();

    final userMessage = StudyChatUiMessage(isUser: true, text: trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
    );

    if (studyChatMessageLooksBlocked(trimmed)) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          StudyChatUiMessage(isUser: false, text: refusalBlockedInjection),
        ],
        isSending: false,
      );
      return null;
    }

    final turns = <StudyChatTurn>[];
    for (final m in state.messages) {
      turns.add(
        StudyChatTurn(
          role: m.isUser ? StudyChatRole.user : StudyChatRole.assistant,
          content: m.text,
        ),
      );
    }

    try {
      final result = await _ref.read(studyChatAiServiceProvider).sendStudyReply(
            majorTitle: majorTitle,
            languageCode: languageCode,
            turns: turns,
            allowedCourses: allowedCourses,
            allowedTopics: allowedTopics,
          );

      final assistantText =
          result.onTopic ? result.replyText : refusalOffTopic;

      state = state.copyWith(
        messages: [
          ...state.messages,
          StudyChatUiMessage(isUser: false, text: assistantText),
        ],
        isSending: false,
      );
      return null;
    } on StudyChatException catch (e) {
      state = state.copyWith(
        messages: state.messages
            .where((m) => m != userMessage)
            .toList(growable: false),
        isSending: false,
      );
      return e.message;
    } catch (e) {
      state = state.copyWith(
        messages: state.messages
            .where((m) => m != userMessage)
            .toList(growable: false),
        isSending: false,
      );
      return e.toString();
    }
  }

  void clearConversation() {
    state = const StudyChatState();
  }
}
