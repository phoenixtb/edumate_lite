import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../domain/interfaces/input_source.dart';
import '../../core/errors/exceptions.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

/// PDF input adapter using Syncfusion PDF
class PdfInputAdapter implements InputSource {
  @override
  String get sourceType => 'pdf';

  @override
  String get displayName => 'PDF Document';

  @override
  List<String> get supportedExtensions => ['.pdf'];

  @override
  bool canHandle(dynamic input) {
    if (input is String) {
      return input.toLowerCase().endsWith('.pdf');
    }
    if (input is File) {
      return input.path.toLowerCase().endsWith('.pdf');
    }
    return false;
  }

  @override
  Stream<ExtractionProgress> extractContent(dynamic input) async* {
    if (!canHandle(input)) {
      yield ExtractionProgress(
        progress: 0,
        error: 'Invalid input type. Expected PDF file path or File object.',
      );
      return;
    }

    try {
      // Get file path
      final String filePath;
      if (input is String) {
        filePath = input;
      } else if (input is File) {
        filePath = input.path;
      } else {
        throw FileException('Invalid input type');
      }

      // Check file exists
      final file = File(filePath);
      if (!await file.exists()) {
        yield ExtractionProgress(
          progress: 0,
          error: 'File not found: $filePath',
        );
        return;
      }

      // Validate file size
      final fileSizeBytes = await file.length();
      final fileSizeMb = fileSizeBytes / (1024 * 1024);

      AppLogger.info('📄 PDF size: ${fileSizeMb.toStringAsFixed(1)}MB');

      if (fileSizeMb > AppConstants.maxPdfSizeMb) {
        final error =
            'PDF too large: ${fileSizeMb.toStringAsFixed(1)}MB. '
            'Max allowed: ${AppConstants.maxPdfSizeMb}MB';
        AppLogger.error('❌ $error');
        yield ExtractionProgress(progress: 0, error: error);
        return;
      }

      // Load PDF document
      yield ExtractionProgress(progress: 0.1, currentPage: 'Loading PDF...');

      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final pageCount = document.pages.count;

      AppLogger.info('📄 PDF pages: $pageCount');

      // Validate page count
      if (pageCount > AppConstants.maxPdfPages) {
        final error =
            'PDF too long: $pageCount pages. '
            'Max allowed: ${AppConstants.maxPdfPages} pages';
        AppLogger.error('❌ $error');
        document.dispose();
        yield ExtractionProgress(progress: 0, error: error);
        return;
      }

      // === QUICK SCANNED PDF DETECTION ===
      // Do a fast full-document text extraction first to detect scanned PDFs
      yield ExtractionProgress(
        progress: 0.15,
        currentPage: 'Checking document type...',
      );

      final quickExtractor = PdfTextExtractor(document);
      final fullText = quickExtractor.extractText();
      final totalCharsQuick = fullText.length;
      final charsPerPage = totalCharsQuick / pageCount;

      // Threshold: If less than 50 chars per page, likely scanned
      // A typical text page has 2000-3000 chars, so 50 is very conservative
      const scannedThreshold = 50;

      if (charsPerPage < scannedThreshold) {
        AppLogger.warning(
          '⚠️ [PDF] Scanned PDF detected: $totalCharsQuick total chars, '
          '${charsPerPage.toStringAsFixed(1)} chars/page (threshold: $scannedThreshold)',
        );

        document.dispose();

        final message = totalCharsQuick == 0
            ? 'No text found - this is a scanned/image-based PDF'
            : 'Very low text content (${charsPerPage.toStringAsFixed(0)} chars/page) - likely scanned';

        yield ExtractionProgress(
          progress: 0.2,
          currentPage: 'Scanned PDF detected',
          isComplete: true,
          error: 'SCANNED_PDF:$message',
          totalPages: pageCount,
          extractionMethod: 'text',
          textDensity: charsPerPage / 500, // Normalize to expected
        );
        return;
      }

      AppLogger.info(
        '📄 [PDF] Text PDF confirmed: ${charsPerPage.toStringAsFixed(0)} chars/page',
      );

      // STREAMING EXTRACTION: Process in batches, yield incrementally
      final batchSize = AppConstants.pdfPageBatchSize;
      final buffer = StringBuffer();
      bool hasAnyText = false;
      int totalCharsExtracted = 0;

      for (
        var batchStart = 0;
        batchStart < pageCount;
        batchStart += batchSize
      ) {
        final batchEnd = (batchStart + batchSize < pageCount)
            ? batchStart + batchSize
            : pageCount;

        AppLogger.debug('📄 Extracting pages ${batchStart + 1}-$batchEnd');
        buffer.clear();

        // Extract batch of pages with layout information
        for (var i = batchStart; i < batchEnd; i++) {
          final pageNum = i + 1;
          int pageChars = 0;

          // Extract text with layout (preserves paragraph structure)
          final textExtractor = PdfTextExtractor(document);
          final textLines = textExtractor.extractTextLines(
            startPageIndex: i,
            endPageIndex: i,
          );

          if (textLines.isNotEmpty) {
            // Group text lines into paragraphs based on vertical spacing
            var currentParagraph = StringBuffer();
            var lastY = 0.0;

            for (final line in textLines) {
              final text = line.text.trim();
              if (text.isEmpty) continue;

              // Detect paragraph break (significant vertical gap > 15pt)
              if (lastY > 0 && (line.bounds.top - lastY) > 15) {
                // Save current paragraph
                if (currentParagraph.isNotEmpty) {
                  buffer.writeln(currentParagraph.toString().trim());
                  buffer.writeln(); // Paragraph separator (double newline)
                  currentParagraph.clear();
                }
              }

              // Add line to current paragraph (space between lines in same paragraph)
              if (currentParagraph.isNotEmpty) {
                currentParagraph.write(' ');
              }
              currentParagraph.write(text);
              pageChars += text.length;
              lastY = line.bounds.bottom;
              hasAnyText = true;
            }

            // Save final paragraph
            if (currentParagraph.isNotEmpty) {
              buffer.writeln(currentParagraph.toString().trim());
              buffer.writeln(); // Page separator
            }
          }

          totalCharsExtracted += pageChars;

          // Report progress with metadata
          final progress = 0.2 + (0.7 * pageNum / pageCount);
          yield ExtractionProgress(
            progress: progress,
            currentPage: 'Page $pageNum/$pageCount',
            pageNumber: pageNum,
            totalPages: pageCount,
            extractionMethod: 'text',
            textDensity: pageChars / 500.0, // Normalize to expected ~500 chars/page
          );
        }

        // Yield batch text immediately, then clear buffer
        if (buffer.isNotEmpty) {
          yield ExtractionProgress(
            progress: 0.1 + (0.8 * batchEnd / pageCount),
            currentPage: 'Pages ${batchStart + 1}-$batchEnd extracted',
            extractedText: buffer.toString(),
            extractionMethod: 'text',
          );
        }
      }

      // Dispose document to free memory
      document.dispose();

      // Calculate overall text density
      final overallDensity = totalCharsExtracted / (pageCount * 500.0);

      AppLogger.info(
        '✅ PDF extraction complete: $pageCount pages, '
        '$totalCharsExtracted chars, density: ${overallDensity.toStringAsFixed(2)}',
      );

      // Final completion signal (scanned detection already done upfront)
      yield ExtractionProgress(
        progress: 1.0,
        currentPage: 'Complete',
        isComplete: true,
        error: hasAnyText ? null : 'No text extracted from PDF',
        totalPages: pageCount,
        extractionMethod: 'text',
        textDensity: overallDensity,
      );
    } catch (e) {
      yield ExtractionProgress(
        progress: 0,
        error: 'Failed to extract PDF content: $e',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getMetadata(dynamic input) async {
    try {
      final String filePath;
      if (input is String) {
        filePath = input;
      } else if (input is File) {
        filePath = input.path;
      } else {
        throw FileException('Invalid input type');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException('File not found');
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      final metadata = <String, dynamic>{
        'pageCount': document.pages.count,
        'fileSize': bytes.length,
        'fileName': file.path.split('/').last,
        'filePath': filePath,
      };

      // Try to extract document info
      if (document.documentInformation.title.isNotEmpty) {
        metadata['title'] = document.documentInformation.title;
      }
      if (document.documentInformation.author.isNotEmpty) {
        metadata['author'] = document.documentInformation.author;
      }
      if (document.documentInformation.subject.isNotEmpty) {
        metadata['subject'] = document.documentInformation.subject;
      }

      document.dispose();

      return metadata;
    } catch (e) {
      throw FileException('Failed to extract metadata: $e');
    }
  }
}
