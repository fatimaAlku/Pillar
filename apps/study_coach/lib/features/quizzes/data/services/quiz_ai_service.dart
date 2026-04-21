import 'dart:async';
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
  return HybridQuizAiService();
});

class HybridQuizAiService implements QuizAiService {
  HybridQuizAiService();
  static const String _googleAiApiKey =
      String.fromEnvironment('GOOGLE_AI_API_KEY');
  static const String _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');

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
    final googleKey = _googleAiApiKey.trim();
    final openAiKey = _openAiApiKey.trim();
    if (googleKey.isEmpty && openAiKey.isEmpty) {
      throw const QuizAiServiceException(
        'AI quiz generation is not configured. Set GOOGLE_AI_API_KEY or OPENAI_API_KEY.',
      );
    }

    Map<String, dynamic> aiPayload;
    try {
      if (googleKey.isNotEmpty) {
        aiPayload = await _requestGeminiQuestions(
          apiKey: googleKey,
          topics: trimmedTopics,
          notesText: normalizedNotes,
          difficulty: difficulty,
          numberOfQuestions: numberOfQuestions,
        );
      } else {
        aiPayload = await _requestOpenAiQuestions(
          apiKey: openAiKey,
          topics: trimmedTopics,
          notesText: normalizedNotes,
          difficulty: difficulty,
          numberOfQuestions: numberOfQuestions,
        );
      }
    } on QuizAiServiceException {
      // If Gemini fails and OpenAI key exists, attempt OpenAI fallback.
      if (googleKey.isNotEmpty && openAiKey.isNotEmpty) {
        aiPayload = await _requestOpenAiQuestions(
          apiKey: openAiKey,
          topics: trimmedTopics,
          notesText: normalizedNotes,
          difficulty: difficulty,
          numberOfQuestions: numberOfQuestions,
        );
      } else {
        rethrow;
      }
    }

    final parsed = QuizAiResponseParser.parseToQuestions(
      data: aiPayload,
      fallbackTopic: fallbackTopic,
    );
    if (parsed.length != numberOfQuestions) {
      throw QuizAiParseException(
        'AI returned ${parsed.length} questions; expected $numberOfQuestions.',
      );
    }
    return _ensureQuestionDiversity(parsed);
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

    final response = await http.post(
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
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QuizAiServiceException(
        'AI provider request failed (${response.statusCode}).',
        details: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const QuizAiParseException(
          'AI provider response must be an object.');
    }
    final body = Map<String, dynamic>.from(decoded);
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const QuizAiParseException('AI response missing choices.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const QuizAiParseException('AI choice must be an object.');
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      throw const QuizAiParseException('AI choice message missing.');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const QuizAiParseException('AI content missing.');
    }

    final parsedPayload = _parseJsonObject(content);
    return parsedPayload;
  }

  static const int _geminiMaxAttempts = 4;
  static final RegExp _geminiRetryAfterRegExp = RegExp(
    r'Please retry in ([\d.]+)\s*s',
    caseSensitive: false,
  );

  static bool _geminiBodyLooksLikeQuota(String body) {
    return body.contains('RESOURCE_EXHAUSTED') ||
        body.contains('Quota exceeded');
  }

  static bool _geminiResponseIsQuotaLimited(int statusCode, String body) {
    if (statusCode == 429) return true;
    if (statusCode == 503 && _geminiBodyLooksLikeQuota(body)) return true;
    return statusCode >= 400 &&
        statusCode < 500 &&
        _geminiBodyLooksLikeQuota(body);
  }

  static Duration _geminiBackoffAfterFailure(int attemptIndex) {
    final seconds = 1 << attemptIndex;
    return Duration(seconds: seconds > 32 ? 32 : seconds);
  }

  static Duration _delayBeforeGeminiRetry(int attemptIndex, String body) {
    final match = _geminiRetryAfterRegExp.firstMatch(body);
    if (match != null) {
      final seconds = double.tryParse(match.group(1) ?? '') ?? 0;
      if (seconds > 0) {
        final ms = (seconds * 1000).ceil() + 400;
        return Duration(milliseconds: ms.clamp(500, 120000));
      }
    }
    return _geminiBackoffAfterFailure(attemptIndex);
  }

  Future<Map<String, dynamic>> _requestGeminiQuestions({
    required String apiKey,
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    required String? notesText,
  }) async {
    final prompt = [
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
      '',
      'Topics: ${topics.isEmpty ? 'General' : topics.join(', ')}',
      notesText == null || notesText.isEmpty
          ? 'Notes: not provided'
          : 'Notes:\n$notesText',
    ].join('\n');

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );
    final requestBody = jsonEncode(<String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'responseMimeType': 'application/json',
      },
    });

    for (var attempt = 0; attempt < _geminiMaxAttempts; attempt++) {
      final lastResponse = await http.post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      final status = lastResponse.statusCode;
      final body = lastResponse.body;
      if (status >= 200 && status < 300) {
        final decoded = jsonDecode(body);
        if (decoded is! Map) {
          throw const QuizAiParseException(
            'Gemini response must be a JSON object.',
          );
        }
        final root = Map<String, dynamic>.from(decoded);
        final text = _extractGeminiText(root);
        return _parseJsonObject(text);
      }

      final isQuota = _geminiResponseIsQuotaLimited(status, body);
      final hasMoreAttempts = attempt < _geminiMaxAttempts - 1;
      if (isQuota && hasMoreAttempts) {
        await Future<void>.delayed(_delayBeforeGeminiRetry(attempt, body));
        continue;
      }

      if (isQuota) {
        throw const QuizAiServiceException(
          'Gemini free-tier quota or rate limit was reached. Wait a few minutes, '
          'try again with shorter notes, review limits at '
          'https://ai.google.dev/gemini-api/docs/rate-limits , enable billing in '
          'Google AI Studio if needed, or set OPENAI_API_KEY so the app can fall '
          'back to OpenAI.',
        );
      }

      throw QuizAiServiceException(
        'AI provider request failed ($status).',
        details: body,
      );
    }

    throw StateError('Gemini request loop exited unexpectedly');
  }

  String _extractGeminiText(Map<String, dynamic> root) {
    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const QuizAiParseException('Gemini response missing candidates.');
    }
    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      throw const QuizAiParseException('Gemini candidate must be an object.');
    }
    final content = firstCandidate['content'];
    if (content is! Map) {
      throw const QuizAiParseException('Gemini candidate missing content.');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const QuizAiParseException('Gemini content missing parts.');
    }
    final firstPart = parts.first;
    if (firstPart is! Map) {
      throw const QuizAiParseException('Gemini content part must be an object.');
    }
    final text = firstPart['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const QuizAiParseException('Gemini content text missing.');
    }
    return text;
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
      final explanation = _requireString(q, 'explanation', i);

      final optionsRaw = q['options'] ?? q['choices'];
      if (optionsRaw is! List || optionsRaw.length != 4) {
        throw QuizAiParseException('Question[$i].options must have 4 items.');
      }
      final options =
          optionsRaw.map((o) => o.toString()).toList(growable: false);
      if (options.any((o) => o.trim().isEmpty)) {
        throw QuizAiParseException('Question[$i].options cannot be empty.');
      }

      final correctIndexRaw = q['correctIndex'] ?? q['answerIndex'];
      final correctIndex = switch (correctIndexRaw) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v),
        _ => null,
      };
      if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
        throw QuizAiParseException('Question[$i].correctIndex must be 0-3.');
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

  static String _requireString(Map<String, dynamic> m, String key, int index) {
    final v = m[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    throw QuizAiParseException(
        'Question[$index].$key must be a non-empty string.');
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
