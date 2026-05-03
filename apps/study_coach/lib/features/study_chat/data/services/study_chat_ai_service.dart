import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/study_chat_turn.dart';

abstract class StudyChatAiService {
  /// Returns the assistant reply for the ongoing study conversation.
  Future<String> sendStudyReply({
    required String majorTitle,
    required String languageCode,
    required List<StudyChatTurn> turns,
  });
}

final studyChatAiServiceProvider = Provider<StudyChatAiService>((ref) {
  return OpenAiStudyChatAiService();
});

class OpenAiStudyChatAiService implements StudyChatAiService {
  OpenAiStudyChatAiService();

  static const String _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const Duration _timeout = Duration(seconds: 60);

  @override
  Future<String> sendStudyReply({
    required String majorTitle,
    required String languageCode,
    required List<StudyChatTurn> turns,
  }) async {
    final key = _openAiApiKey.trim();
    if (key.isEmpty) {
      throw const StudyChatServiceException(
        'Study chat is not configured. Set OPENAI_API_KEY.',
      );
    }
    final normalizedMajor = majorTitle.trim();
    if (normalizedMajor.isEmpty) {
      throw const StudyChatValidationException(
          'Major is required for study chat.');
    }
    if (turns.isEmpty) {
      throw const StudyChatValidationException('No messages to send.');
    }

    final isArabic = languageCode == 'ar';
    final systemLines = <String>[
      if (isArabic) ...[
        'أنت مساعد دراسة لطالب جامعي.',
        'التخصص الدراسي للطالب (وحده المسموح بالإجابة عنه): "$normalizedMajor".',
        'قواعد صارمة:',
        '- أجب فقط عن أسئلة تتعلق بالدراسة الأكاديمية ضمن هذا التخصص: المفاهيم، التعاريف، شرح المواد، التحضير للامتحان، والتفكير النقدي المرتبط بالمجال.',
        '- إذا كان السؤال خارج هذا التخصص، أو ليس لأغراض دراسية (حياة شخصية، ترفيه، نصائح طبية/قانونية، إلخ)، اعتذر بلطف واشرح أنك تقتصر على مساعدة الدراسة في التخصص المذكور فقط.',
        '- لا تقدّم محتوى ضارًا أو غير قانوني. شجّع النزاهة الأكاديمية: ساعِد على الفهم بدل تسليم إجابات جاهزة للمهام المقيّمة عندما يطلب الطالب الحل جملةً دون جهد.',
        '- اكتب جميع ردودك بالعربية.',
      ] else ...[
        'You are a study assistant for a university student.',
        'The student\'s declared major (the ONLY field you may answer within): "$normalizedMajor".',
        'Strict rules:',
        '- Only answer questions that are academic study within this major: concepts, definitions, coursework explanations, exam prep, and critical thinking tied to the discipline.',
        '- If a question is outside this major or not for legitimate study (personal life, entertainment, medical or legal advice, etc.), politely refuse and say you only help with study questions in their stated major.',
        '- Do not provide harmful or illegal content. Encourage academic integrity: teach and guide understanding rather than delivering ready-made graded work when the student asks for answers without effort.',
        '- Write all replies in English.',
      ],
    ];

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemLines.join('\n')},
      ...turns.map((t) {
        final role = t.role == StudyChatRole.user ? 'user' : 'assistant';
        return <String, String>{'role': role, 'content': t.content.trim()};
      }),
    ];

    final response = await http
        .post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: <String, String>{
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'model': 'gpt-4o-mini',
        'temperature': 0.55,
        'messages': messages,
      }),
    )
        .timeout(_timeout, onTimeout: () {
      throw const StudyChatServiceException(
        'Study chat request timed out. Check connection and try again.',
      );
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudyChatServiceException(
        'Study chat request failed (${response.statusCode}).',
        details: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const StudyChatParseException('Invalid response from study chat.');
    }
    final body = Map<String, dynamic>.from(decoded);
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const StudyChatParseException(
          'Study chat response missing content.');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const StudyChatParseException('Invalid study chat choice.');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const StudyChatParseException('Study chat message missing.');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const StudyChatParseException('Study chat reply was empty.');
    }
    return content.trim();
  }
}

sealed class StudyChatException implements Exception {
  const StudyChatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StudyChatValidationException extends StudyChatException {
  const StudyChatValidationException(super.message);
}

class StudyChatParseException extends StudyChatException {
  const StudyChatParseException(super.message);
}

class StudyChatServiceException extends StudyChatException {
  const StudyChatServiceException(super.message, {this.details});
  final String? details;
}
