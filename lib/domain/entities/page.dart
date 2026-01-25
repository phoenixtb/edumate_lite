import 'package:objectbox/objectbox.dart';
import 'material.dart';

/// Represents a single page from a processed material
/// Stores page-level metadata and optional compressed image for reference
@Entity()
class Page {
  @Id()
  int id = 0;

  /// Reference to parent material
  final material = ToOne<Material>();

  /// Page number (1-indexed)
  int pageNumber;

  /// Path to compressed page image (relative to app documents)
  /// Format: page_images/{materialId}/{pageNumber}.jpg
  /// Null if image not stored (fast mode text-based PDFs)
  String? imagePath;

  /// Original page dimensions (in PDF points, 72 points = 1 inch)
  double? width;
  double? height;

  /// How text was extracted from this page
  /// 'text' = Syncfusion programmatic extraction
  /// 'vision' = Gemma Vision OCR from rendered image
  /// 'hybrid' = Vision fallback after text extraction failed
  String extractionMethod;

  /// Text density: chars extracted / expected chars
  /// Low density (<0.1) indicates scanned/image-based page
  /// Used for scanned PDF detection
  double textDensity;

  /// Content type flags for smart filtering
  bool hasEquations;
  bool hasDiagrams;
  bool hasTables;
  bool hasCode;

  /// LLM-generated 1-2 sentence summary of page content
  /// Generated during processing for quick reference
  String? summary;

  /// Number of chunks generated from this page
  int chunkCount;

  /// Timestamps
  @Property(type: PropertyType.date)
  DateTime createdAt;

  Page({
    required this.pageNumber,
    this.imagePath,
    this.width,
    this.height,
    this.extractionMethod = 'text',
    this.textDensity = 1.0,
    this.hasEquations = false,
    this.hasDiagrams = false,
    this.hasTables = false,
    this.hasCode = false,
    this.summary,
    this.chunkCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if this page likely contains scanned content
  bool get isLikelyScanned => textDensity < 0.1;

  /// Check if page image is available for display
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}
