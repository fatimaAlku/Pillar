import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/localization/app_strings.dart';
import '../domain/entities/quiz_question.dart';
import '../domain/entities/quiz_submission_result.dart';

class QuizReportExporter {
  const QuizReportExporter();

  Future<Uint8List> buildQuizReviewReportPdfBytes({
    required QuizSubmissionResult result,
    required AppStrings strings,
    required DateTime generatedAt,
  }) async {
    final doc = PdfDocument();
    try {
      doc.pageSettings.margins.all = 40;

      final grid = PdfGrid();
      grid.columns.add(count: 1);
      grid.allowRowBreakingAcrossPages = true;
      grid.repeatHeader = false;
      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 6, right: 6, top: 6, bottom: 6),
      );

      _addTextRow(
        grid,
        text: strings.quizReport,
        font: PdfStandardFont(
          PdfFontFamily.helvetica,
          18,
          style: PdfFontStyle.bold,
        ),
      );
      _addTextRow(
        grid,
        text: _formatDateTime(generatedAt),
        font: PdfStandardFont(PdfFontFamily.helvetica, 10),
      );

      final percent = (result.scoreFraction * 100).round();
      _addTextRow(
        grid,
        text:
            '${strings.score}: ${result.correctCount}/${result.totalCount} ($percent%)',
        font: PdfStandardFont(PdfFontFamily.helvetica, 14),
      );

      _addSectionTitleRow(grid, strings.weakTopics);
      if (result.weakTopics.isEmpty) {
        _addTextRow(
          grid,
          text: strings.noWeakTopics,
          font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        );
      } else {
        final weakLines = result.weakTopics.map((t) {
          return '• ${t.topicTitle} — ${strings.incorrectCount(t.incorrectCount)}';
        }).join('\n');
        _addTextRow(
          grid,
          text: weakLines,
          font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        );
      }

      _addSectionTitleRow(grid, strings.review);

      for (var i = 0; i < result.questions.length; i++) {
        final q = result.questions[i];
        final selected = result.selectedByQuestionId[q.id];
        final isUnanswered = selected == null;
        final yourAnswer =
            isUnanswered ? strings.unanswered : q.options[selected];
        final correctAnswer = q.options[q.correctIndex];

        final explanationText = q.explanation?.trim();
        final explanationLine = (explanationText == null ||
                explanationText.isEmpty)
            ? null
            : strings.explanation(explanationText);

        _addQuestionBlockRow(
          grid: grid,
          index: i + 1,
          question: q,
          yourAnswer: yourAnswer,
          correctAnswer: correctAnswer,
          explanationLine: explanationLine,
          strings: strings,
        );
      }

      grid.draw(page: doc.pages.add(), bounds: Rect.zero);
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  void _addSectionTitleRow(PdfGrid grid, String title) {
    _addTextRow(
      grid,
      text: title,
      font: PdfStandardFont(
        PdfFontFamily.helvetica,
        12,
        style: PdfFontStyle.bold,
      ),
    );
  }

  void _addQuestionBlockRow({
    required PdfGrid grid,
    required int index,
    required QuizQuestion question,
    required String yourAnswer,
    required String correctAnswer,
    required String? explanationLine,
    required AppStrings strings,
  }) {
    final buffer = StringBuffer();
    buffer
      ..writeln('Q$index: ${question.prompt}')
      ..writeln('${strings.topicTitleLabel}: ${question.topicTitle}')
      ..writeln(strings.yourAnswer(yourAnswer))
      ..writeln(strings.correctAnswer(correctAnswer));
    if (explanationLine != null) {
      buffer.writeln(explanationLine);
    }

    _addTextRow(
      grid,
      text: buffer.toString().trim(),
      font: PdfStandardFont(PdfFontFamily.helvetica, 11),
    );
  }

  void _addTextRow(PdfGrid grid, {required String text, required PdfFont font}) {
    final row = grid.rows.add();
    row.cells[0].value = PdfTextElement(
      text: text,
      font: font,
      format: PdfStringFormat(
        wordWrap: PdfWordWrapType.word,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }
}

