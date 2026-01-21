import 'dart:io';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../../domain/interfaces/input_source.dart';
import '../../domain/services/vision_service.dart';
import '../../core/errors/exceptions.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

/// PDF input adapter using AI Vision for OCR
/// Renders each page to an image and uses Gemma Vision to extract text
/// Slower but better for scanned PDFs, complex layouts, equations, diagrams
class VisionPdfAdapter implements InputSource {
  @override
  String get sourceType => 'pdf_vision';

  @override
  String get displayName => 'PDF (AI Vision)';

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

    PdfDocument? document;

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

      AppLogger.info('📄 [VISION-PDF] Size: ${fileSizeMb.toStringAsFixed(1)}MB');

      if (fileSizeMb > AppConstants.maxPdfSizeMb) {
        final error =
            'PDF too large: ${fileSizeMb.toStringAsFixed(1)}MB. '
            'Max allowed: ${AppConstants.maxPdfSizeMb}MB';
        yield ExtractionProgress(progress: 0, error: error);
        return;
      }

      // Load PDF document
      yield ExtractionProgress(
        progress: 0.05,
        currentPage: 'Loading PDF...',
      );

      document = await PdfDocument.openFile(filePath);
      final pageCount = document.pagesCount;

      AppLogger.info('📄 [VISION-PDF] Pages: $pageCount');

      // Validate page count (lower limit for vision processing due to speed)
      final maxVisionPages = 50; // Vision processing is slow, limit pages
      if (pageCount > maxVisionPages) {
        final error =
            'PDF too long for Vision processing: $pageCount pages. '
            'Max allowed: $maxVisionPages pages. Try "Fast" mode for longer PDFs.';
        yield ExtractionProgress(progress: 0, error: error);
        return;
      }

      bool hasAnyText = false;

      // Process each page with Vision
      for (var pageNum = 1; pageNum <= pageCount; pageNum++) {
        yield ExtractionProgress(
          progress: 0.1 + (0.8 * (pageNum - 1) / pageCount),
          currentPage: 'Processing page $pageNum/$pageCount with AI Vision...',
          pageNumber: pageNum,
          totalPages: pageCount,
          extractionMethod: 'vision',
        );

        AppLogger.debug('📄 [VISION-PDF] Rendering page $pageNum');

        // Get page and render to image
        final page = await document.getPage(pageNum);

        try {
          // Render at 2x scale for better OCR quality
          // Typical PDF is 612x792 points, so 2x = 1224x1584 pixels
          final scale = 2.0;
          final pageImage = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.jpeg,
            quality: 85,
            backgroundColor: '#FFFFFF',
          );

          if (pageImage == null || pageImage.bytes.isEmpty) {
            AppLogger.warning('⚠️ [VISION-PDF] Empty render for page $pageNum');
            continue;
          }

          AppLogger.debug(
            '📄 [VISION-PDF] Page $pageNum rendered: ${pageImage.bytes.length} bytes',
          );

          // Extract text using Vision
          yield ExtractionProgress(
            progress: 0.1 + (0.8 * (pageNum - 0.5) / pageCount),
            currentPage: 'Extracting text from page $pageNum...',
            pageNumber: pageNum,
            totalPages: pageCount,
            extractionMethod: 'vision',
          );

          final extractedText = await _extractTextWithVision(
            pageImage.bytes,
            pageNum,
            pageCount,
          );

          if (extractedText.isNotEmpty) {
            hasAnyText = true;
          }

          // Yield extracted text AND page image for storage
          yield ExtractionProgress(
            progress: 0.1 + (0.8 * pageNum / pageCount),
            currentPage: 'Page $pageNum extracted',
            extractedText: extractedText.isNotEmpty
                ? '--- Page $pageNum ---\n$extractedText\n\n'
                : null,
            pageNumber: pageNum,
            totalPages: pageCount,
            pageImageBytes: pageImage.bytes, // Include image for saving
            extractionMethod: 'vision',
            textDensity: 1.0, // Vision always extracts something
            pageWidth: page.width,
            pageHeight: page.height,
          );
        } finally {
          await page.close();
        }
      }

      AppLogger.info('✅ [VISION-PDF] Extraction complete: $pageCount pages');

      // Final completion signal
      yield ExtractionProgress(
        progress: 1.0,
        currentPage: 'Complete',
        isComplete: true,
        error: hasAnyText ? null : 'No text could be extracted from PDF',
      );
    } catch (e, stackTrace) {
      AppLogger.error('❌ [VISION-PDF] Extraction failed', e, stackTrace);
      yield ExtractionProgress(
        progress: 0,
        error: 'Failed to extract PDF content: $e',
      );
    } finally {
      await document?.close();
    }
  }

  /// Extract text from page image using VisionService
  Future<String> _extractTextWithVision(
    Uint8List imageBytes,
    int pageNum,
    int totalPages,
  ) async {
    try {
      // Use VisionService.extractText() which has proper OCR prompt
      final result = await VisionService.instance.extractText(imageBytes);

      AppLogger.debug(
        '📄 [VISION-PDF] Page $pageNum: ${result.length} chars extracted',
      );
      return result;
    } catch (e) {
      AppLogger.error(
        '❌ [VISION-PDF] Vision extraction failed for page $pageNum: $e',
      );
      return '';
    }
  }

  @override
  Future<Map<String, dynamic>> getMetadata(dynamic input) async {
    PdfDocument? document;
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

      document = await PdfDocument.openFile(filePath);

      final metadata = <String, dynamic>{
        'pageCount': document.pagesCount,
        'fileSize': await file.length(),
        'fileName': file.path.split('/').last,
        'filePath': filePath,
        'processingMode': 'vision',
      };

      return metadata;
    } catch (e) {
      throw FileException('Failed to extract metadata: $e');
    } finally {
      await document?.close();
    }
  }
}
