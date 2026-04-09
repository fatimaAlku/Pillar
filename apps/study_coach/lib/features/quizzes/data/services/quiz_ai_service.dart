import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return FirebaseFunctionsQuizAiService(ref.watch(functionsProvider));
});

class FirebaseFunctionsQuizAiService implements QuizAiService {
  FirebaseFunctionsQuizAiService(this._functions);

  final FirebaseFunctions _functions;

  /// Cloud Function should return either:
  /// - a `Map` already matching the schema, or
  /// - a JSON `String` that decodes into that schema.
  ///
  /// Callable name: `generateQuizQuestions`
  /// Request payload includes a schema contract to enforce structured output.
  @override
  Future<List<QuizQuestion>> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
  }) async {
    final trimmedTopics = topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final normalizedNotes = notesText?.trim();

    if (trimmedTopics.isEmpty && (normalizedNotes == null || normalizedNotes.isEmpty)) {
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

    try {
      final callable = _functions.httpsCallable('generateQuizQuestions');
      final result = await callable.call(<String, dynamic>{
        'topics': trimmedTopics,
        'notesText': normalizedNotes,
        'difficulty': difficulty,
        'numberOfQuestions': numberOfQuestions,
        'responseFormat': QuizAiJsonContract.schemaV1,
      });

      final parsed = QuizAiResponseParser.parseToQuestions(
        data: result.data,
        fallbackTopic: trimmedTopics.isEmpty ? 'General' : trimmedTopics.first,
      );

      if (parsed.length != numberOfQuestions) {
        // Not fatal, but enforce a safe expectation for callers.
        throw QuizAiParseException(
          'Expected $numberOfQuestions questions but got ${parsed.length}.',
        );
      }

      return parsed;
    } on FirebaseFunctionsException catch (e) {
      throw QuizAiServiceException(
        'Quiz generation failed (${e.code}).',
        details: e.message,
      );
    } on QuizAiException {
      rethrow;
    } catch (e) {
      throw const QuizAiServiceException('Quiz generation failed unexpectedly.');
    }
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

      final prompt = _requireString(q, 'prompt', i);
      final explanation = _requireString(q, 'explanation', i);

      final optionsRaw = q['options'];
      if (optionsRaw is! List || optionsRaw.length != 4) {
        throw QuizAiParseException('Question[$i].options must have 4 items.');
      }
      final options = optionsRaw.map((o) => o.toString()).toList(growable: false);
      if (options.any((o) => o.trim().isEmpty)) {
        throw QuizAiParseException('Question[$i].options cannot be empty.');
      }

      final correctIndexRaw = q['correctIndex'];
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
      final topicTitle =
          (q['topicTitle'] as Object?)?.toString().trim() ?? fallbackTopic.trim();

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
    throw QuizAiParseException('Question[$index].$key must be a non-empty string.');
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

