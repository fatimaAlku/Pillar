import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    String languageCode = 'en',
    String quizEmphasis = 'balanced',
  });
}

final quizAiServiceProvider = Provider<QuizAiService>((ref) {
  return CloudFunctionsQuizAiService(FirebaseFunctions.instance);
});

/// Calls [generateQuizQuestions] on Cloud Functions (OpenAI key stays server-side).
/// On failure, falls back to a local note-based quiz so the runner still works offline.
class CloudFunctionsQuizAiService implements QuizAiService {
  CloudFunctionsQuizAiService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<QuizQuestion>> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
    String languageCode = 'en',
    String quizEmphasis = 'balanced',
  }) async {
    final trimmedTopics =
        topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final normalizedNotes = notesText?.trim();
    final hasNotes = normalizedNotes != null && normalizedNotes.isNotEmpty;

    if (!hasNotes && trimmedTopics.isEmpty) {
      throw const QuizAiValidationException(
        'Provide notes or at least one topic so the quiz can be generated.',
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
    final allowedTopics =
        trimmedTopics.isEmpty ? const <String>['General'] : trimmedTopics;
    final emphasis =
        quizEmphasis.trim().isEmpty ? 'balanced' : quizEmphasis.trim();

    try {
      final callable = _functions.httpsCallable('generateQuizQuestions');
      final result = await callable.call(<String, dynamic>{
        'topics': trimmedTopics,
        if (hasNotes) 'notesText': normalizedNotes,
        'difficulty': difficulty.trim(),
        'numberOfQuestions': numberOfQuestions,
        'languageCode': languageCode,
        'quizEmphasis': emphasis,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final parsed = QuizAiResponseParser.parseToQuestions(
        data: data,
        fallbackTopic: fallbackTopic,
        allowedTopics: allowedTopics,
      );
      if (parsed.length > numberOfQuestions) {
        return _ensureQuestionDiversity(
          parsed.take(numberOfQuestions).toList(growable: false),
        );
      }
      return _ensureQuestionDiversity(parsed);
    } on FirebaseFunctionsException catch (e) {
      final code = e.code;
      if (code == 'invalid-argument' ||
          code == 'failed-precondition' ||
          code == 'unauthenticated') {
        throw QuizAiServiceException(
          e.message ?? 'Quiz generation was rejected.',
          details: e.details?.toString(),
        );
      }
      return _localFallbackQuiz(
        notesText: normalizedNotes,
        topics: allowedTopics,
        numberOfQuestions: numberOfQuestions,
        fallbackTopic: fallbackTopic,
        languageCode: languageCode,
      );
    } on QuizAiException {
      return _localFallbackQuiz(
        notesText: normalizedNotes,
        topics: allowedTopics,
        numberOfQuestions: numberOfQuestions,
        fallbackTopic: fallbackTopic,
        languageCode: languageCode,
      );
    } catch (_) {
      return _localFallbackQuiz(
        notesText: normalizedNotes,
        topics: allowedTopics,
        numberOfQuestions: numberOfQuestions,
        fallbackTopic: fallbackTopic,
        languageCode: languageCode,
      );
    }
  }
}

/// Fallback quiz used when the cloud callable is unreachable. Uses note text
/// when available, otherwise synthesises facts from the topic bank so the
/// runner remains usable without uploaded notes.
List<QuizQuestion> _localFallbackQuiz({
  required String? notesText,
  required List<String> topics,
  required int numberOfQuestions,
  required String fallbackTopic,
  required String languageCode,
}) {
  final isArabic = languageCode == 'ar';
  final factsFromNotes = (notesText ?? '')
      .split(RegExp(r'[\n\r]+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 6)
      .toList();
  final normalizedFacts = factsFromNotes.isNotEmpty
      ? factsFromNotes
      : _factsFromTopicBank(topics: topics, isArabic: isArabic);

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
      if (isArabic) ...[
        'تجاهل هذا وركّز بدلًا من ذلك على: $distractorA',
        'اعتمد على الحفظ فقط وتجاوز الفهم ($distractorB)',
        'اتبع العكس تمامًا: $distractorC',
      ] else ...[
        'Ignore this and instead focus on: $distractorA',
        'Use only memorization and skip reasoning ($distractorB)',
        'Do the opposite approach: $distractorC',
      ],
    ];

    final hasNotes = factsFromNotes.isNotEmpty;
    final topicTitle = topics.isEmpty
        ? fallbackTopic
        : topics[i % topics.length];
    questions.add(
      QuizQuestion(
        id: 'local_q_${i + 1}',
        topicId: 'topic_${_slugTopicId(topicTitle)}',
        topicTitle: topicTitle,
        prompt: hasNotes
            ? (isArabic
                ? 'وفقًا لملاحظاتك، أي عبارة هي الأدق؟'
                : 'According to your notes, which statement is most accurate?')
            : (isArabic
                ? 'بالنسبة لموضوع "$topicTitle"، أي عبارة أكثر دقة؟'
                : 'For "$topicTitle", which statement is most accurate?'),
        options: options,
        correctIndex: 0,
        explanation: hasNotes
            ? (isArabic
                ? 'تم إنشاء هذا السؤال من ملاحظاتك أثناء انشغال خدمة الذكاء الاصطناعي.'
                : 'Generated from your notes while AI service is busy.')
            : (isArabic
                ? 'تم إنشاء هذا السؤال من بنك مواضيع المقرر المعتمد.'
                : 'Generated from the approved course topic bank.'),
      ),
    );
  }
  return _ensureQuestionDiversity(questions);
}

List<String> _factsFromTopicBank({
  required List<String> topics,
  required bool isArabic,
}) {
  if (topics.isEmpty) {
    return isArabic
        ? const [
            'راجع أساسيات الموضوع والتعاريف بعناية',
            'قسّم المسألة إلى خطوات واضحة ومتسلسلة',
            'اختبر بأمثلة صغيرة قبل زيادة التعقيد',
            'تحقّق من الأخطاء وصححها بعد كل محاولة',
          ]
        : const [
            'Review the topic fundamentals and definitions carefully',
            'Break problems into clear step-by-step actions',
            'Test with small examples before scaling complexity',
            'Check and correct mistakes after each attempt',
          ];
  }

  final facts = <String>[];
  for (final t in topics) {
    if (isArabic) {
      facts
        ..add('يركز "$t" على المفاهيم الأساسية والتطبيق العملي')
        ..add('يتعمق فهم "$t" بربط التعريفات بالأمثلة')
        ..add('يتطلب "$t" تحديد الأنماط واختبارها على حالات صغيرة')
        ..add('يفيد في "$t" استعمال التعاريف بدقة قبل حل المسائل');
    } else {
      facts
        ..add('$t focuses on core principles and practical application')
        ..add('$t builds understanding by connecting definitions to examples')
        ..add('$t requires identifying patterns and testing them on small cases')
        ..add('$t benefits from using definitions accurately before solving');
    }
  }
  return facts;
}

String _slugTopicId(String s) {
  final lower = s.trim().toLowerCase();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
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

class QuizAiResponseParser {
  static List<QuizQuestion> parseToQuestions({
    required Object? data,
    required String fallbackTopic,
    List<String> allowedTopics = const <String>[],
  }) {
    final root = _coerceToMap(data);
    final rawQuestions = root['questions'];
    if (rawQuestions is! List) {
      throw const QuizAiParseException('Missing "questions" array.');
    }

    final canonicalAllowed = <String>[
      for (final t in allowedTopics)
        if (t.trim().isNotEmpty) t.trim(),
    ];

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

      final rawTopicTitle =
          (q['topicTitle'] as Object?)?.toString().trim() ?? '';
      final canonicalTitle = _resolveCanonicalTopic(
        candidate: rawTopicTitle,
        prompt: prompt,
        allowed: canonicalAllowed,
        fallback: fallbackTopic,
      );

      final rawTopicId = (q['topicId'] as Object?)?.toString().trim();
      final topicId = (rawTopicId != null && rawTopicId.isNotEmpty)
          ? rawTopicId
          : 'topic_${_slug(canonicalTitle)}';

      questions.add(
        QuizQuestion(
          id: (q['id'] as Object?)?.toString().trim().isNotEmpty == true
              ? (q['id'] as Object).toString()
              : 'ai_q_${i + 1}',
          topicId: topicId,
          topicTitle: canonicalTitle,
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

  /// Snap any AI-emitted topic to the closest user-allowed topic so weak
  /// topics surface specific course topics (e.g. "Trees") instead of generic
  /// labels like "Common beginner mistakes".
  static String _resolveCanonicalTopic({
    required String candidate,
    required String prompt,
    required List<String> allowed,
    required String fallback,
  }) {
    if (allowed.isEmpty) {
      return candidate.isEmpty ? fallback : candidate;
    }

    final candidateLower = candidate.toLowerCase();
    if (candidate.isNotEmpty) {
      for (final t in allowed) {
        if (t.toLowerCase() == candidateLower) return t;
      }
      for (final t in allowed) {
        final tl = t.toLowerCase();
        if (tl.isEmpty) continue;
        if (candidateLower.contains(tl) || tl.contains(candidateLower)) {
          return t;
        }
      }
    }

    final promptLower = prompt.toLowerCase();
    final promptTokens = promptLower
        .split(RegExp(r'[^a-z0-9\u0600-\u06ff]+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    String? bestMatch;
    var bestScore = 0;
    for (final t in allowed) {
      final tl = t.toLowerCase();
      if (tl.isEmpty) continue;
      var score = 0;
      if (promptLower.contains(tl)) {
        score = tl.length * 2;
      } else {
        for (final word in tl.split(RegExp(r'\s+'))) {
          if (word.length < 3) continue;
          if (promptLower.contains(word)) {
            score += word.length * 2;
            continue;
          }
          // Stem-aware match: e.g. allowed "Hashing" matches prompt "hash".
          final prefix = word.substring(0, word.length < 4 ? word.length : 4);
          for (final tok in promptTokens) {
            if (tok.length < 3) continue;
            if (tok.startsWith(prefix) || word.startsWith(tok)) {
              score += prefix.length;
              break;
            }
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = t;
      }
    }
    if (bestMatch != null) return bestMatch;

    return allowed.first;
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
