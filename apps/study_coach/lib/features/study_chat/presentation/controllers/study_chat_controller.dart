import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../roadmap/domain/major_catalog.dart';
import '../../data/services/study_chat_ai_service.dart';
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

  Future<String?> sendUserMessage({
    required String text,
    required String languageCode,
    required String? majorId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final majorTitle = majorTitleFromId(majorId);
    if (majorTitle.isEmpty) {
      return 'no_major';
    }

    final userMessage = StudyChatUiMessage(isUser: true, text: trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
    );

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
      final reply = await _ref.read(studyChatAiServiceProvider).sendStudyReply(
            majorTitle: majorTitle,
            languageCode: languageCode,
            turns: turns,
          );
      state = state.copyWith(
        messages: [
          ...state.messages,
          StudyChatUiMessage(isUser: false, text: reply),
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
