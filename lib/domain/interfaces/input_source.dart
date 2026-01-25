/// Abstract interface for all input sources
/// Implement this to add new input methods (e.g., URL, audio, handwriting)
abstract class InputSource {
  /// Unique identifier for this input type
  String get sourceType;

  /// Human-readable name
  String get displayName;

  /// Supported file extensions (empty for non-file sources)
  List<String> get supportedExtensions;

  /// Check if this source can handle the given input
  bool canHandle(dynamic input);

  /// Extract raw text content from the input
  /// Returns a stream for progress updates on large files
  Stream<ExtractionProgress> extractContent(dynamic input);

  /// Get metadata about the input (page count, dimensions, etc.)
  Future<Map<String, dynamic>> getMetadata(dynamic input);
}

/// Progress update during content extraction
class ExtractionProgress {
  final double progress; // 0.0 to 1.0
  final String? currentPage;
  final String? extractedText;
  final bool isComplete;
  final String? error;

  // === Enhanced metadata for Phase 1 ===

  /// Current page number being processed (1-indexed)
  final int? pageNumber;

  /// Total pages in document
  final int? totalPages;

  /// Page image bytes (for saving, compressed JPEG)
  /// Only populated for vision-processed pages
  final List<int>? pageImageBytes;

  /// Extraction method used: 'text', 'vision'
  final String? extractionMethod;

  /// Text density for this page (chars / expected chars)
  /// Low values (<0.1) indicate scanned/image-based content
  final double? textDensity;

  /// Page dimensions (PDF points)
  final double? pageWidth;
  final double? pageHeight;

  ExtractionProgress({
    required this.progress,
    this.currentPage,
    this.extractedText,
    this.isComplete = false,
    this.error,
    this.pageNumber,
    this.totalPages,
    this.pageImageBytes,
    this.extractionMethod,
    this.textDensity,
    this.pageWidth,
    this.pageHeight,
  });

  /// Check if this page appears to be scanned (low text density)
  bool get isLikelyScanned =>
      textDensity != null && textDensity! < 0.1;
}

