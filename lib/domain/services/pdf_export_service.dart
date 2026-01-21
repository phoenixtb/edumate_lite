import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../entities/worksheet.dart';
import '../../core/utils/logger.dart';

/// Service for exporting worksheets to styled PDF documents
class PdfExportService {
  // Styling constants
  static const double _pageMargin = 54.0; // 0.75 inches
  static const double _footerHeight = 30.0;
  static const double _problemSpacing = 20.0;
  static const double _answerLineHeight = 24.0;
  static const int _answerLineCount = 3;

  /// Export worksheet to PDF bytes
  ///
  /// [worksheet] - The worksheet to export
  /// [includeAnswers] - Whether to include answer key section
  /// [includeSteps] - Whether to include step-by-step solutions in answer key
  Future<Uint8List> exportWorksheet(
    Worksheet worksheet, {
    bool includeAnswers = true,
    bool includeSteps = false,
  }) async {
    AppLogger.info(
        '📄 [PDF] Exporting worksheet: "${worksheet.title}" (${worksheet.problemCount} problems)');

    // Create PDF document
    final document = PdfDocument();
    document.pageSettings.margins.all = _pageMargin;
    document.pageSettings.size = PdfPageSize.letter;

    // Define fonts
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18,
        style: PdfFontStyle.bold);
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 14,
        style: PdfFontStyle.bold);
    final problemFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final problemBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 12,
        style: PdfFontStyle.bold);
    final answerFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

    // Colors
    final headerColor = PdfColor(33, 150, 243); // Blue
    final lineColor = PdfColor(200, 200, 200); // Light gray

    // Get page dimensions
    final pageWidth =
        document.pageSettings.size.width - (2 * _pageMargin);
    final pageHeight =
        document.pageSettings.size.height - (2 * _pageMargin);

    // === WORKSHEET PAGES ===
    var currentPage = document.pages.add();
    var graphics = currentPage.graphics;
    var yPosition = 0.0;
    var pageNumber = 1;
    var totalPages = 1; // Will update later

    // Draw header on first page
    yPosition = _drawHeader(
      graphics,
      worksheet,
      pageWidth,
      titleFont,
      subtitleFont,
      headerColor,
    );

    // Draw "Name: ___" and "Date: ___" fields
    yPosition = _drawStudentFields(
      graphics,
      yPosition,
      pageWidth,
      problemFont,
      lineColor,
    );

    yPosition += 20;

    // Draw problems
    for (var i = 0; i < worksheet.problems.length; i++) {
      final problem = worksheet.problems[i];
      final problemNumber = i + 1;

      // Estimate space needed for this problem
      final estimatedHeight = _estimateProblemHeight(
        problem,
        pageWidth,
        problemFont,
      );

      // Check if we need a new page
      if (yPosition + estimatedHeight > pageHeight - _footerHeight) {
        // Draw footer on current page
        _drawFooter(graphics, pageWidth, pageHeight, pageNumber, footerFont);

        // Add new page
        currentPage = document.pages.add();
        graphics = currentPage.graphics;
        yPosition = 0;
        pageNumber++;
        totalPages++;
      }

      // Draw problem
      yPosition = _drawProblem(
        currentPage,
        graphics,
        problem,
        problemNumber,
        yPosition,
        pageWidth,
        problemFont,
        problemBoldFont,
        lineColor,
      );

      yPosition += _problemSpacing;
    }

    // Draw footer on last worksheet page
    _drawFooter(graphics, pageWidth, pageHeight, pageNumber, footerFont);

    // === ANSWER KEY PAGES ===
    if (includeAnswers) {
      currentPage = document.pages.add();
      graphics = currentPage.graphics;
      yPosition = 0;
      pageNumber++;
      totalPages++;

      // Answer key header
      graphics.drawString(
        'Answer Key',
        headerFont,
        bounds: Rect.fromLTWH(0, yPosition, pageWidth, 30),
      );
      yPosition += 40;

      graphics.drawLine(
        PdfPen(headerColor, width: 2),
        Offset(0, yPosition),
        Offset(pageWidth, yPosition),
      );
      yPosition += 20;

      // Draw answers
      for (var i = 0; i < worksheet.problems.length; i++) {
        final problem = worksheet.problems[i];
        final problemNumber = i + 1;

        // Estimate space needed
        var estimatedHeight = 25.0;
        if (includeSteps && problem.hasSteps) {
          estimatedHeight += problem.steps.length * 18.0;
        }

        // Check if we need a new page
        if (yPosition + estimatedHeight > pageHeight - _footerHeight) {
          _drawFooter(graphics, pageWidth, pageHeight, pageNumber, footerFont);

          currentPage = document.pages.add();
          graphics = currentPage.graphics;
          yPosition = 0;
          pageNumber++;
          totalPages++;
        }

        // Draw answer
        yPosition = _drawAnswer(
          currentPage,
          graphics,
          problem,
          problemNumber,
          yPosition,
          pageWidth,
          answerFont,
          problemBoldFont,
          includeSteps,
        );

        yPosition += 10;
      }

      // Footer on last answer page
      _drawFooter(graphics, pageWidth, pageHeight, pageNumber, footerFont);
    }

    // Save and return bytes
    final bytes = Uint8List.fromList(await document.save());
    document.dispose();

    AppLogger.info('✅ [PDF] Export complete: ${bytes.length} bytes, $totalPages pages');

    return bytes;
  }

  /// Draw page header
  double _drawHeader(
    PdfGraphics graphics,
    Worksheet worksheet,
    double pageWidth,
    PdfFont titleFont,
    PdfFont subtitleFont,
    PdfColor accentColor,
  ) {
    var yPos = 0.0;

    // Title
    graphics.drawString(
      worksheet.title,
      titleFont,
      bounds: Rect.fromLTWH(0, yPos, pageWidth, 25),
    );
    yPos += 28;

    // Subtitle line (subject, grade, date)
    final dateStr = DateFormat('MMMM d, yyyy').format(worksheet.generatedAt);
    final subtitle =
        'Subject: ${_capitalize(worksheet.subject)} | Grade: ${worksheet.gradeLevel} | Date: $dateStr';

    graphics.drawString(
      subtitle,
      subtitleFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      bounds: Rect.fromLTWH(0, yPos, pageWidth, 15),
    );
    yPos += 20;

    // Accent line
    graphics.drawLine(
      PdfPen(accentColor, width: 2),
      Offset(0, yPos),
      Offset(pageWidth, yPos),
    );
    yPos += 15;

    return yPos;
  }

  /// Draw student name/date fields
  double _drawStudentFields(
    PdfGraphics graphics,
    double yPosition,
    double pageWidth,
    PdfFont font,
    PdfColor lineColor,
  ) {
    final halfWidth = (pageWidth - 40) / 2;

    // Name field
    graphics.drawString(
      'Name:',
      font,
      bounds: Rect.fromLTWH(0, yPosition, 50, 20),
    );
    graphics.drawLine(
      PdfPen(lineColor),
      Offset(50, yPosition + 15),
      Offset(halfWidth, yPosition + 15),
    );

    // Date field
    graphics.drawString(
      'Date:',
      font,
      bounds: Rect.fromLTWH(halfWidth + 40, yPosition, 50, 20),
    );
    graphics.drawLine(
      PdfPen(lineColor),
      Offset(halfWidth + 85, yPosition + 15),
      Offset(pageWidth, yPosition + 15),
    );

    return yPosition + 30;
  }

  /// Estimate height needed for a problem
  double _estimateProblemHeight(
    Problem problem,
    double pageWidth,
    PdfFont font,
  ) {
    // Rough estimate: ~15 chars per line at 12pt font on letter page
    final charsPerLine = (pageWidth / 7).floor();
    final questionLines = (problem.question.length / charsPerLine).ceil();
    final questionHeight = questionLines * 16.0;

    // Answer space
    final answerHeight = _answerLineCount * _answerLineHeight;

    return questionHeight + answerHeight + 20;
  }

  /// Draw a problem on the page
  double _drawProblem(
    PdfPage page,
    PdfGraphics graphics,
    Problem problem,
    int number,
    double yPosition,
    double pageWidth,
    PdfFont font,
    PdfFont boldFont,
    PdfColor lineColor,
  ) {
    // Problem number
    final numberStr = '$number.';
    graphics.drawString(
      numberStr,
      boldFont,
      bounds: Rect.fromLTWH(0, yPosition, 25, 20),
    );

    // Problem text (with word wrap)
    final textLayout = PdfTextElement(
      text: problem.question,
      font: font,
    ).draw(
      page: page,
      bounds: Rect.fromLTWH(30, yPosition, pageWidth - 30, 200),
    );

    yPosition = (textLayout?.bounds.bottom ?? yPosition + 20) + 10;

    // Answer lines
    for (var i = 0; i < _answerLineCount; i++) {
      graphics.drawLine(
        PdfPen(lineColor),
        Offset(30, yPosition),
        Offset(pageWidth, yPosition),
      );
      yPosition += _answerLineHeight;
    }

    return yPosition;
  }

  /// Draw an answer in the answer key
  double _drawAnswer(
    PdfPage page,
    PdfGraphics graphics,
    Problem problem,
    int number,
    double yPosition,
    double pageWidth,
    PdfFont font,
    PdfFont boldFont,
    bool includeSteps,
  ) {
    // Problem number and answer
    final answerText = '$number. ${problem.answer}';
    final textLayout = PdfTextElement(
      text: answerText,
      font: font,
    ).draw(
      page: page,
      bounds: Rect.fromLTWH(0, yPosition, pageWidth, 100),
    );

    yPosition = (textLayout?.bounds.bottom ?? yPosition + 18) + 5;

    // Steps if requested
    if (includeSteps && problem.hasSteps) {
      final stepFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      for (var i = 0; i < problem.steps.length; i++) {
        final stepText = '   Step ${i + 1}: ${problem.steps[i]}';
        graphics.drawString(
          stepText,
          stepFont,
          brush: PdfSolidBrush(PdfColor(80, 80, 80)),
          bounds: Rect.fromLTWH(0, yPosition, pageWidth, 18),
        );
        yPosition += 16;
      }
    }

    return yPosition;
  }

  /// Draw page footer
  void _drawFooter(
    PdfGraphics graphics,
    double pageWidth,
    double pageHeight,
    int pageNumber,
    PdfFont font,
  ) {
    final footerY = pageHeight - 10;

    // Page number centered
    final pageText = 'Page $pageNumber';
    graphics.drawString(
      pageText,
      font,
      brush: PdfSolidBrush(PdfColor(120, 120, 120)),
      bounds: Rect.fromLTWH(0, footerY, pageWidth, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // EduMate branding on left
    graphics.drawString(
      'Generated by EduMate',
      font,
      brush: PdfSolidBrush(PdfColor(150, 150, 150)),
      bounds: Rect.fromLTWH(0, footerY, pageWidth / 2, 15),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
