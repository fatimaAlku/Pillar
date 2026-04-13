import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/state/app_providers.dart';
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
  return HybridQuizAiService(ref.watch(functionsProvider));
});

class HybridQuizAiService implements QuizAiService {
  HybridQuizAiService(this._functions);

  final FirebaseFunctions _functions;
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

    if (trimmedTopics.isEmpty &&
        (normalizedNotes == null || normalizedNotes.isEmpty)) {
      throw const QuizAiValidationException(
        'Provide at least one topic or notes text.',
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
    final localFallback = QuizFallbackBuilder.build(
      topics: trimmedTopics,
      notesText: normalizedNotes,
      difficulty: difficulty,
      numberOfQuestions: numberOfQuestions,
    );

    // 1) Primary path: call AI directly from client to avoid Secret Manager
    // requirements on Spark plan. Key should be provided via --dart-define.
    try {
      final key = _openAiApiKey.trim();
      if (key.isNotEmpty) {
        final aiPayload = await _requestOpenAiQuestions(
          apiKey: key,
          topics: trimmedTopics,
          notesText: normalizedNotes,
          difficulty: difficulty,
          numberOfQuestions: numberOfQuestions,
        );

        final parsed = QuizAiResponseParser.parseToQuestions(
          data: aiPayload,
          fallbackTopic: fallbackTopic,
        );
        if (parsed.length == numberOfQuestions) {
          return _ensureQuestionDiversity(parsed);
        }
      }
    } on QuizAiException {
      // Try server callable fallback next.
    } catch (_) {
      // Try server callable fallback next.
    }

    // 2) Secondary path: Firebase callable fallback (deterministic server output).
    try {
      final result = await _callGenerateQuizEndpoint(
        topics: trimmedTopics,
        notesText: normalizedNotes,
        difficulty: difficulty,
        numberOfQuestions: numberOfQuestions,
      );

      final parsed = QuizAiResponseParser.parseToQuestions(
        data: result.data,
        fallbackTopic: fallbackTopic,
      );

      if (parsed.length == numberOfQuestions) {
        return _ensureQuestionDiversity(parsed);
      }
    } catch (_) {
      // Local deterministic fallback below.
    }

    // 3) Last-resort local fallback keeps the feature always functional.
    return _ensureQuestionDiversity(localFallback);
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

  Future<HttpsCallableResult<dynamic>> _callGenerateQuizEndpoint({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    required String? notesText,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateQuizQuestions');
      return await callable.call(<String, dynamic>{
        'topics': topics,
        'notesText': notesText,
        'difficulty': difficulty,
        'numberOfQuestions': numberOfQuestions,
        'responseFormat': QuizAiJsonContract.schemaV1,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') {
        rethrow;
      }
    }

    // Backward-compatible fallback for older functions deployments.
    final fallbackCallable = _functions.httpsCallable('generateQuiz');
    return await fallbackCallable.call(<String, dynamic>{
      'topicIds': topics,
      'notesText': notesText,
      'difficulty': difficulty,
      'numberOfQuestions': numberOfQuestions,
      'responseFormat': QuizAiJsonContract.schemaV1,
    });
  }
}

/// Structured JSON contract (v1).
///
/// Expected response shape:
/// {
///   "questions": [
///     {
///       "id": "optional-string",
///       "topicId": "optional-string",
///       "topicTitle": "optional-string",
///       "prompt": "string",
///       "options": ["string","string","string","string"],
///       "correctIndex": 0,
///       "explanation": "string"
///     }
///   ]
/// }
class QuizAiJsonContract {
  static const Map<String, dynamic> schemaV1 = <String, dynamic>{
    'version': 1,
    'type': 'object',
    'required': ['questions'],
    'properties': {
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'required': ['prompt', 'options', 'correctIndex', 'explanation'],
          'properties': {
            'id': {'type': 'string'},
            'topicId': {'type': 'string'},
            'topicTitle': {'type': 'string'},
            'prompt': {'type': 'string'},
            'options': {
              'type': 'array',
              'minItems': 4,
              'maxItems': 4,
              'items': {'type': 'string'},
            },
            'correctIndex': {'type': 'integer', 'minimum': 0, 'maximum': 3},
            'explanation': {'type': 'string'},
          },
        },
      },
    },
  };
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

class QuizFallbackBuilder {
  static List<QuizQuestion> build({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    required String? notesText,
  }) {
    final sourceTopics = topics.isEmpty ? const ['General'] : topics;
    final hasNotes = notesText != null && notesText.trim().isNotEmpty;
    final normalizedDifficulty = difficulty.toLowerCase();
    final difficultyHint = switch (normalizedDifficulty) {
      'easy' => 'intro',
      'hard' => 'advanced',
      _ => 'balanced',
    };

    return List.generate(numberOfQuestions, (index) {
      final topicTitle = sourceTopics[index % sourceTopics.length];
      final topicId = 'topic_${_slug(topicTitle)}';
      final correctStatement = _correctStatementFor(
        topicTitle: topicTitle,
        difficultyHint: difficultyHint,
        index: index,
      );
      final distractors = _distractorsFor(topicTitle: topicTitle, index: index);
      final correctIndex = index % 4;
      final options = List<String>.filled(4, '');
      var distractorPointer = 0;
      for (var optionIndex = 0; optionIndex < 4; optionIndex++) {
        if (optionIndex == correctIndex) {
          options[optionIndex] = correctStatement;
        } else {
          options[optionIndex] = distractors[distractorPointer++];
        }
      }

      return QuizQuestion(
        id: 'ai_q_${index + 1}',
        topicId: topicId,
        topicTitle: topicTitle,
        prompt: _promptFor(
          topicTitle: topicTitle,
          index: index,
          hasNotes: hasNotes,
          difficultyHint: difficultyHint,
        ),
        options: options,
        correctIndex: correctIndex,
        explanation:
            'Fallback question tuned for $normalizedDifficulty difficulty.',
      );
    });
  }

  static String _promptFor({
    required String topicTitle,
    required int index,
    required bool hasNotes,
    required String difficultyHint,
  }) {
    final prompts = <String>[
      'Which statement is most accurate about $topicTitle?',
      'Which option best explains the key idea in $topicTitle?',
      'Choose the most reliable summary of $topicTitle.',
      'Which statement would be best to remember for $topicTitle?',
      'Which choice correctly describes $topicTitle at a $difficultyHint level?',
    ];
    final notesPrompts = <String>[
      'Based on your notes, which statement best matches $topicTitle?',
      'From your notes, what is the strongest summary of $topicTitle?',
      'Using your notes, which option is most accurate for $topicTitle?',
      'According to your notes, which statement correctly captures $topicTitle?',
      'From your notes at a $difficultyHint level, which statement fits $topicTitle?',
    ];
    final pool = hasNotes ? notesPrompts : prompts;
    return pool[index % pool.length];
  }

  static String _correctStatementFor({
    required String topicTitle,
    required String difficultyHint,
    required int index,
  }) {
    final variants = <String>[
      '$topicTitle focuses on core principles and practical application ($difficultyHint).',
      '$topicTitle builds understanding by connecting concepts step by step.',
      '$topicTitle is best learned by identifying patterns and testing examples.',
      '$topicTitle requires using definitions accurately before solving problems.',
    ];
    return variants[index % variants.length];
  }

  static List<String> _distractorsFor({
    required String topicTitle,
    required int index,
  }) {
    final base = <String>[
      '$topicTitle is mainly about memorizing unrelated facts.',
      '$topicTitle never uses structured reasoning.',
      '$topicTitle can be solved by guessing without understanding.',
      '$topicTitle avoids using definitions and examples.',
      '$topicTitle is only relevant in one narrow scenario.',
      '$topicTitle has no link between theory and practice.',
    ];
    return <String>[
      base[index % base.length],
      base[(index + 2) % base.length],
      base[(index + 4) % base.length],
    ];
  }

  static String _slug(String s) {
    final lower = s.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final cleaned = replaced.replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'general' : cleaned;
  }
}
