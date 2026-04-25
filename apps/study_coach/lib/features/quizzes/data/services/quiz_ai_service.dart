import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/quiz_question.dart';

/// Quiz generation service contract (no UI).
abstract class QuizAiService {
  /// Input: topics/notes, difficulty, number of questions.
  ///
  /// Output: list of questions with 4 options, correct answer, explanation.
  Future<List<QuizQuestion>> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
  });
}

final quizAiServiceProvider = Provider<QuizAiService>((ref) {
  return OpenAiQuizAiService();
});

class OpenAiQuizAiService implements QuizAiService {
  OpenAiQuizAiService();
  static const String _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const Duration _openAiRequestTimeout = Duration(seconds: 45);

  @override
  Future<List<QuizQuestion>> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
  }) async {
    final trimmedTopics =
        topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final normalizedNotes = notesText?.trim();

    if (normalizedNotes == null || normalizedNotes.isEmpty) {
      throw const QuizAiValidationException(
        'Notes are required. Paste or upload notes so AI can generate the quiz.',
      );
    }
    if (difficulty.trim().isEmpty) {
      throw const QuizAiValidationException('Difficulty must not be empty.');
    }
    if (numberOfQuestions <= 0) {
      throw const QuizAiValidationException(
        'Number of questions must be greater than 0.',
      );
    }

    final fallbackTopic =
        trimmedTopics.isEmpty ? 'General' : trimmedTopics.first;
    final openAiKey = _openAiApiKey.trim();
    if (openAiKey.isEmpty) {
      throw const QuizAiServiceException(
        'AI quiz generation is not configured. Set OPENAI_API_KEY.',
      );
    }

    try {
      final aiPayload = await _requestOpenAiQuestions(
        apiKey: openAiKey,
        topics: trimmedTopics,
        notesText: normalizedNotes,
        difficulty: difficulty,
        numberOfQuestions: numberOfQuestions,
      );

      final parsed = QuizAiResponseParser.parseToQuestions(
        data: aiPayload,
        fallbackTopic: fallbackTopic,
      );
      if (parsed.length > numberOfQuestions) {
        return _ensureQuestionDiversity(
          parsed.take(numberOfQuestions).toList(growable: false),
        );
      }
      return _ensureQuestionDiversity(parsed);
    } on QuizAiException {
      // Fallback keeps quiz flow available when provider is rate-limited/unavailable.
      return _generateLocalFallbackQuiz(
        notesText: normalizedNotes,
        numberOfQuestions: numberOfQuestions,
        fallbackTopic: fallbackTopic,
      );
    }
  }

  List<QuizQuestion> _generateLocalFallbackQuiz({
    required String notesText,
    required int numberOfQuestions,
    required String fallbackTopic,
  }) {
    final facts = notesText
        .split(RegExp(r'[\n\r]+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 6)
        .toList();
    final normalizedFacts = facts.isEmpty
        ? <String>[
            'Review the topic fundamentals and definitions carefully',
            'Break problems into clear step-by-step actions',
            'Test with small examples before scaling complexity',
            'Check and correct mistakes after each attempt',
          ]
        : facts;

    final questions = <QuizQuestion>[];
    for (var i = 0; i < numberOfQuestions; i++) {
      final fact = normalizedFacts[i % normalizedFacts.length];
      final distractorA =
          normalizedFacts[(i + 1) % normalizedFacts.length].toLowerCase();
      final distractorB =
          normalizedFacts[(i + 2) % normalizedFacts.length].toLowerCase();
      final distractorC =
          normalizedFacts[(i + 3) % normalizedFacts.length].toLowerCase();

      final options = <String>[
        fact,
        'Ignore this and instead focus on: $distractorA',
        'Use only memorization and skip reasoning ($distractorB)',
        'Do the opposite approach: $distractorC',
      ];

      questions.add(
        QuizQuestion(
          id: 'local_q_${i + 1}',
          topicId: 'topic_${QuizAiResponseParser._slug(fallbackTopic)}',
          topicTitle: fallbackTopic,
          prompt: 'According to your notes, which statement is most accurate?',
          options: options,
          correctIndex: 0,
          explanation: 'Generated from your notes while AI service is busy.',
        ),
      );
    }
    return _ensureQuestionDiversity(questions);
  }

  Future<Map<String, dynamic>> _requestOpenAiQuestions({
    required String apiKey,
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    required String? notesText,
  }) async {
    final systemPrompt = [
      'You generate high-quality MCQ quizzes for university students.',
      'Return JSON only with shape: {"questions":[{"prompt":"string","options":["a","b","c","d"],"correctIndex":0,"explanation":"string","topicTitle":"string"}]}',
      'Rules:',
      '- Use the notes as the primary source of truth.',
      '- Every correct answer must be directly supported by the notes.',
      '- Keep distractors plausible but incorrect relative to the notes.',
      '- Exactly 4 options per question.',
      '- correctIndex must be 0,1,2,3.',
      '- Return exactly $numberOfQuestions questions.',
      '- Difficulty level is $difficulty.',
    ].join('\n');
    final userPrompt = [
      'Topics: ${topics.isEmpty ? 'General' : topics.join(', ')}',
      notesText == null || notesText.isEmpty
          ? 'Notes: not provided'
          : 'Notes:\n$notesText',
    ].join('\n\n');

    final response = await http
        .post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'model': 'gpt-4o-mini',
        'temperature': 0.4,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    )
        .timeout(_openAiRequestTimeout, onTimeout: () {
      throw const QuizAiServiceException(
        'OpenAI request timed out. Check connection and try again.',
      );
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QuizAiServiceException(
        'OpenAI request failed (${response.statusCode}).',
        details: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const QuizAiParseException(
        'OpenAI response must be a JSON object.',
      );
    }
    final body = Map<String, dynamic>.from(decoded);
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const QuizAiParseException('OpenAI response missing choices.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const QuizAiParseException('OpenAI choice must be an object.');
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      throw const QuizAiParseException('OpenAI choice message missing.');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const QuizAiParseException('OpenAI content missing.');
    }

    return _parseJsonObject(content);
  }

  List<QuizQuestion> _ensureQuestionDiversity(List<QuizQuestion> questions) {
    final usedPrompts = <String>{};
    final usedOptionSets = <String>{};
    final sanitized = <QuizQuestion>[];

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      var prompt = q.prompt.trim();
      if (prompt.isEmpty) {
        prompt = 'Question ${i + 1}';
      }
      final promptKey = prompt.toLowerCase();
      if (!usedPrompts.add(promptKey)) {
        prompt = '$prompt (variation ${i + 1})';
      }

      final options = List<String>.from(q.options);
      final optionValuesInQuestion = <String>{};
      for (var j = 0; j < options.length; j++) {
        var value = options[j].trim();
        if (value.isEmpty) {
          value = 'Option ${j + 1} for question ${i + 1}';
        }
        final dedupeKey = value.toLowerCase();
        if (!optionValuesInQuestion.add(dedupeKey)) {
          value = '$value (alt ${j + 1})';
          optionValuesInQuestion.add(value.toLowerCase());
        }
        options[j] = value;
      }

      final optionSetKey = options.map((e) => e.toLowerCase()).join('||');
      if (!usedOptionSets.add(optionSetKey)) {
        for (var j = 0; j < options.length; j++) {
          options[j] = '${options[j]} [set ${i + 1}]';
        }
        usedOptionSets.add(options.map((e) => e.toLowerCase()).join('||'));
      }

      sanitized.add(
        QuizQuestion(
          id: q.id,
          topicId: q.topicId,
          topicTitle: q.topicTitle,
          prompt: prompt,
          options: options,
          correctIndex: q.correctIndex,
          explanation: q.explanation,
        ),
      );
    }

    return sanitized;
  }

  Map<String, dynamic> _parseJsonObject(String input) {
    final direct = _tryParseJson(input);
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(input);
    if (fenced != null) {
      final block = fenced.group(1);
      final fromFence = _tryParseJson(block ?? '');
      if (fromFence is Map) return Map<String, dynamic>.from(fromFence);
    }

    throw const QuizAiParseException(
      'Could not parse JSON object from AI response.',
    );
  }

  Object? _tryParseJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}

class QuizAiResponseParser {
  static List<QuizQuestion> parseToQuestions({
    required Object? data,
    required String fallbackTopic,
  }) {
    final root = _coerceToMap(data);
    final rawQuestions = root['questions'];
    if (rawQuestions is! List) {
      throw const QuizAiParseException('Missing "questions" array.');
    }

    final questions = <QuizQuestion>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      final item = rawQuestions[i];
      if (item is! Map) {
        throw QuizAiParseException('Question[$i] must be an object.');
      }
      final q = Map<String, dynamic>.from(item);

      final prompt = _requireAnyString(q, ['prompt', 'question'], i, 'prompt');
      final explanation = _optionalString(
            q,
            ['explanation', 'rationale', 'reasoning'],
          ) ??
          'Review your notes for a detailed explanation.';

      final optionsRaw = q['options'] ?? q['choices'];
      if (optionsRaw is! List || optionsRaw.length < 4) {
        throw QuizAiParseException(
          'Question[$i].options must have at least 4 items.',
        );
      }
      final options =
          optionsRaw.take(4).map(_coerceOptionText).toList(growable: false);
      if (options.any((o) => o.trim().isEmpty)) {
        throw QuizAiParseException('Question[$i].options cannot be empty.');
      }

      final correctIndex = _resolveCorrectIndex(q, options);
      if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
        throw QuizAiParseException(
          'Question[$i].correctIndex must resolve to 0-3.',
        );
      }

      final topicId = (q['topicId'] as Object?)?.toString().trim();
      final topicTitle = (q['topicTitle'] as Object?)?.toString().trim() ??
          fallbackTopic.trim();

      questions.add(
        QuizQuestion(
          id: (q['id'] as Object?)?.toString().trim().isNotEmpty == true
              ? (q['id'] as Object).toString()
              : 'ai_q_${i + 1}',
          topicId: (topicId != null && topicId.isNotEmpty)
              ? topicId
              : 'topic_${_slug(fallbackTopic)}',
          topicTitle: topicTitle.isEmpty ? fallbackTopic : topicTitle,
          prompt: prompt,
          options: options,
          correctIndex: correctIndex,
          explanation: explanation,
        ),
      );
    }

    if (questions.isEmpty) {
      throw const QuizAiParseException('No questions returned.');
    }
    return questions;
  }

  static Map<String, dynamic> _coerceToMap(Object? data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw const QuizAiParseException('AI response JSON must be an object.');
    }
    throw const QuizAiParseException('Unsupported AI response type.');
  }

  static String _requireAnyString(
    Map<String, dynamic> m,
    List<String> keys,
    int index,
    String canonicalKey,
  ) {
    for (final key in keys) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    throw QuizAiParseException(
      'Question[$index].$canonicalKey must be a non-empty string.',
    );
  }

  static String? _optionalString(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  static String _coerceOptionText(Object? rawOption) {
    if (rawOption is Map) {
      final optionMap = Map<String, dynamic>.from(rawOption);
      final text = _optionalString(
        optionMap,
        ['text', 'option', 'label', 'value', 'answer'],
      );
      if (text != null) return text;
    }
    return (rawOption ?? '').toString().trim();
  }

  static int? _resolveCorrectIndex(
      Map<String, dynamic> q, List<String> options) {
    final correctIndexRaw = q['correctIndex'] ?? q['answerIndex'];
    final fromIndex = _coerceIndex(correctIndexRaw);
    if (fromIndex != null) return fromIndex;

    final correctAnswerRaw =
        q['correctAnswer'] ?? q['answer'] ?? q['correct_option'];
    final answer = correctAnswerRaw?.toString().trim();
    if (answer == null || answer.isEmpty) return null;

    final oneBased = int.tryParse(answer);
    if (oneBased != null) {
      if (oneBased >= 1 && oneBased <= 4) return oneBased - 1;
      if (oneBased >= 0 && oneBased <= 3) return oneBased;
    }

    final letter = answer.toUpperCase();
    const letters = <String, int>{
      'A': 0,
      'B': 1,
      'C': 2,
      'D': 3,
    };
    final fromLetter = letters[letter];
    if (fromLetter != null) return fromLetter;

    final cleaned = answer.replaceFirst(RegExp(r'^[A-D][\).\:\-\s]+'), '');
    for (var idx = 0; idx < options.length; idx++) {
      final option = options[idx].trim().toLowerCase();
      if (option == answer.toLowerCase() || option == cleaned.toLowerCase()) {
        return idx;
      }
    }
    return null;
  }

  static int? _coerceIndex(Object? value) {
    return switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
  }

  static String _slug(String s) {
    final lower = s.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

sealed class QuizAiException implements Exception {
  const QuizAiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class QuizAiValidationException extends QuizAiException {
  const QuizAiValidationException(super.message);
}

class QuizAiParseException extends QuizAiException {
  const QuizAiParseException(super.message);
}

class QuizAiServiceException extends QuizAiException {
  const QuizAiServiceException(super.message, {this.details});
  final String? details;
}
