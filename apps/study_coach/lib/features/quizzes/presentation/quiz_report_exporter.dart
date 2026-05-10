import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/localization/app_strings.dart';
import '../domain/entities/quiz_question.dart';
import '../domain/entities/quiz_submission_result.dart';

class QuizReportExporter {
  const QuizReportExporter();

  static const String _regularFontAsset =
      'assets/fonts/NotoSansArabic-Regular.ttf';
  static const String _boldFontAsset = 'assets/fonts/NotoSansArabic-Bold.ttf';

  Future<Uint8List> buildQuizReviewReportPdfBytes({
    required QuizSubmissionResult result,
    required AppStrings strings,
    required DateTime generatedAt,
  }) async {
    final regularBytes = await _loadFontBytes(_regularFontAsset);
    final boldBytes = await _loadFontBytes(_boldFontAsset);

    final titleFont = PdfTrueTypeFont(boldBytes, 18);
    final smallFont = PdfTrueTypeFont(regularBytes, 10);
    final scoreFont = PdfTrueTypeFont(regularBytes, 14);
    final sectionFont = PdfTrueTypeFont(boldBytes, 12);
    final bodyFont = PdfTrueTypeFont(regularBytes, 11);

    final format = _stringFormat(strings);

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
        font: titleFont,
        format: format,
      );
      _addTextRow(
        grid,
        text: _formatDateTime(generatedAt),
        font: smallFont,
        format: format,
      );

      final percent = (result.scoreFraction * 100).round();
      _addTextRow(
        grid,
        text:
            '${strings.score}: ${result.correctCount}/${result.totalCount} ($percent%)',
        font: scoreFont,
        format: format,
      );

      final link = result.linkContext;
      if (link != null && link.hasSubject) {
        _addTextRow(
          grid,
          text: '${strings.quizLinkedScopeLabel}: ${link.displayLine}',
          font: bodyFont,
          format: format,
        );
      }

      _addSectionTitleRow(grid, strings.weakTopics, sectionFont, format);
      if (result.weakTopics.isEmpty) {
        _addTextRow(
          grid,
          text: strings.noWeakTopics,
          font: bodyFont,
          format: format,
        );
      } else {
        final weakLines = result.weakTopics.map((t) {
          return '• ${t.topicTitle} — ${strings.incorrectCount(t.incorrectCount)}';
        }).join('\n');
        _addTextRow(
          grid,
          text: weakLines,
          font: bodyFont,
          format: format,
        );
      }

      _addSectionTitleRow(grid, strings.review, sectionFont, format);

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
          font: bodyFont,
          format: format,
        );
      }

      grid.draw(page: doc.pages.add(), bounds: Rect.zero);
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    } finally {
      doc.dispose();
    }
  }

  Future<List<int>> _loadFontBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List().toList(growable: false);
  }

  PdfStringFormat _stringFormat(AppStrings strings) {
    final rtl = strings.isArabicLocale;
    return PdfStringFormat(
      wordWrap: PdfWordWrapType.word,
      textDirection:
          rtl ? PdfTextDirection.rightToLeft : PdfTextDirection.leftToRight,
      alignment: rtl ? PdfTextAlignment.right : PdfTextAlignment.left,
    );
  }

  void _addSectionTitleRow(
    PdfGrid grid,
    String title,
    PdfFont font,
    PdfStringFormat format,
  ) {
    _addTextRow(grid, text: title, font: font, format: format);
  }

  void _addQuestionBlockRow({
    required PdfGrid grid,
    required int index,
    required QuizQuestion question,
    required String yourAnswer,
    required String correctAnswer,
    required String? explanationLine,
    required AppStrings strings,
    required PdfFont font,
    required PdfStringFormat format,
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
      font: font,
      format: format,
    );
  }

  void _addTextRow(
    PdfGrid grid, {
    required String text,
    required PdfFont font,
    required PdfStringFormat format,
  }) {
    final row = grid.rows.add();
    row.cells[0].value = PdfTextElement(
      text: text,
      font: font,
      format: format,
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
