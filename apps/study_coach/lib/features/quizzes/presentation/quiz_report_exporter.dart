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
    final fonts = await _fontsForLocale(strings);
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
        font: fonts.titleFont,
        format: format,
      );
      _addTextRow(
        grid,
        text: _formatDateTime(generatedAt),
        font: fonts.smallFont,
        format: format,
      );

      final percent = (result.scoreFraction * 100).round();
      _addTextRow(
        grid,
        text:
            '${strings.score}: ${result.correctCount}/${result.totalCount} ($percent%)',
        font: fonts.scoreFont,
        format: format,
      );

      final link = result.linkContext;
      if (link != null && link.hasSubject) {
        _addTextRow(
          grid,
          text: '${strings.quizLinkedScopeLabel}: ${link.displayLine}',
          font: fonts.bodyFont,
          format: format,
        );
      }

      _addSectionTitleRow(grid, strings.weakTopics, fonts.sectionFont, format);
      if (result.weakTopics.isEmpty) {
        _addTextRow(
          grid,
          text: strings.noWeakTopics,
          font: fonts.bodyFont,
          format: format,
        );
      } else {
        final weakLines = result.weakTopics.map((t) {
          return '• ${t.topicTitle} — ${strings.incorrectCount(t.incorrectCount)}';
        }).join('\n');
        _addTextRow(
          grid,
          text: weakLines,
          font: fonts.bodyFont,
          format: format,
        );
      }

      _addSectionTitleRow(grid, strings.review, fonts.sectionFont, format);

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
          font: fonts.bodyFont,
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

  /// Noto Sans Arabic does not reliably include Latin glyphs for English quiz
  /// text; Syncfusion then draws blank letters while punctuation still shows.
  /// Use standard PDF fonts (Helvetica) for LTR locales.
  Future<_QuizReportFonts> _fontsForLocale(AppStrings strings) async {
    if (strings.isArabicLocale) {
      final regularBytes = await _loadFontBytes(_regularFontAsset);
      final boldBytes = await _loadFontBytes(_boldFontAsset);
      return _QuizReportFonts(
        titleFont: PdfTrueTypeFont(boldBytes, 18),
        smallFont: PdfTrueTypeFont(regularBytes, 10),
        scoreFont: PdfTrueTypeFont(regularBytes, 14),
        sectionFont: PdfTrueTypeFont(boldBytes, 12),
        bodyFont: PdfTrueTypeFont(regularBytes, 11),
      );
    }
    return _QuizReportFonts(
      titleFont: PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      ),
      smallFont: PdfStandardFont(PdfFontFamily.helvetica, 10),
      scoreFont: PdfStandardFont(PdfFontFamily.helvetica, 14),
      sectionFont: PdfStandardFont(
        PdfFontFamily.helvetica,
        12,
        style: PdfFontStyle.bold,
      ),
      bodyFont: PdfStandardFont(PdfFontFamily.helvetica, 11),
    );
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

final class _QuizReportFonts {
  const _QuizReportFonts({
    required this.titleFont,
    required this.smallFont,
    required this.scoreFont,
    required this.sectionFont,
    required this.bodyFont,
  });

  final PdfFont titleFont;
  final PdfFont smallFont;
  final PdfFont scoreFont;
  final PdfFont sectionFont;
  final PdfFont bodyFont;
}
