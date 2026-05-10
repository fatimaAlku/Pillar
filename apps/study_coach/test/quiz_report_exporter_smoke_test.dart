import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/localization/app_strings.dart';
import '../lib/features/quizzes/domain/entities/quiz_question.dart';
import '../lib/features/quizzes/domain/entities/quiz_submission_result.dart';
import '../lib/features/quizzes/presentation/quiz_report_exporter.dart';

class _ExportResult {
  final Object? error;
  final StackTrace? stackTrace;
  final Uint8List? bytes;

  const _ExportResult({
    required this.error,
    required this.stackTrace,
    required this.bytes,
  });
}

class _ExportHost extends StatefulWidget {
  const _ExportHost({
    required this.result,
    required this.done,
    this.languageCode = 'en',
  });

  final QuizSubmissionResult result;
  final ValueSetter<_ExportResult> done;
  final String languageCode;

  @override
  State<_ExportHost> createState() => _ExportHostState();
}

class _ExportHostState extends State<_ExportHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final exporter = const QuizReportExporter();
      try {
        final strings = AppStrings.forLanguageCode(widget.languageCode);
        final bytes = await exporter.buildQuizReviewReportPdfBytes(
          result: widget.result,
          strings: strings,
          generatedAt: DateTime(2026, 4, 29, 12, 0, 0),
        );
        widget.done(
          _ExportResult(
            error: null,
            stackTrace: null,
            bytes: bytes,
          ),
        );
      } catch (e, st) {
        widget.done(
          _ExportResult(
            error: e,
            stackTrace: st,
            bytes: null,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

void main() {
  testWidgets('QuizReportExporter creates a PDF', (tester) async {
    final result = QuizSubmissionResult(
      questions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'What is the primary difference between a syntax and a logic error?',
          options: [
            'A syntax error prevents code from running, while a logic error allows it to run but produces incorrect results.',
            'A syntax error allows code to run, while a logic error prevents it.',
            'Both are the same.',
            'Neither affects code execution.',
          ],
          correctIndex: 0,
          topicId: 't1',
          topicTitle: 'Programming Foundations',
          explanation:
              'A syntax error prevents code from running due to incorrect formatting, while a logic error allows running but produces incorrect results.',
        ),
      ],
      selectedByQuestionId: const {
        'q1': 1,
      },
      correctCount: 0,
      totalCount: 1,
      weakTopics: const [
        WeakTopic(topicId: 't1', topicTitle: 'Programming Foundations', incorrectCount: 1),
      ],
    );

    _ExportResult? exportResult;
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: _ExportHost(
          result: result,
          done: (_ExportResult r) {
            exportResult = r;
            completer.complete();
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await completer.future;

    expect(exportResult, isNotNull);
    expect(exportResult!.error, isNull, reason: exportResult!.stackTrace?.toString());
    expect(exportResult!.bytes, isNotNull);
    expect(exportResult!.bytes!.length, greaterThan(100));
  });

  testWidgets('QuizReportExporter creates a PDF in Arabic (RTL)', (tester) async {
    final result = QuizSubmissionResult(
      questions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'ما الفرق بين خطأ نحوي وخطأ منطقي؟',
          options: [
            'النحوي يمنع التشغيل، والمنطقي يعطي نتائج خاطئة.',
            'المنطقي يمنع التشغيل.',
            'لا فرق.',
            'لا أثر.',
          ],
          correctIndex: 0,
          topicId: 't1',
          topicTitle: 'أساسيات البرمجة',
          explanation:
              'النحوي يمنع التشغيل بسبب الصيغة، والمنطقي يسمح بالتشغيل لكن النتائج خاطئة.',
        ),
      ],
      selectedByQuestionId: const {'q1': 1},
      correctCount: 0,
      totalCount: 1,
      weakTopics: const [
        WeakTopic(
          topicId: 't1',
          topicTitle: 'أساسيات البرمجة',
          incorrectCount: 1,
        ),
      ],
    );

    _ExportResult? exportResult;
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: _ExportHost(
          languageCode: 'ar',
          result: result,
          done: (_ExportResult r) {
            exportResult = r;
            completer.complete();
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await completer.future;

    expect(exportResult, isNotNull);
    expect(exportResult!.error, isNull, reason: exportResult!.stackTrace?.toString());
    expect(exportResult!.bytes, isNotNull);
    expect(exportResult!.bytes!.length, greaterThan(100));
  });
}

