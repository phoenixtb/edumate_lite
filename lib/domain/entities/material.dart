import 'package:objectbox/objectbox.dart';

/// Represents an uploaded educational material
@Entity()
class Material {
  @Id()
  int id = 0;

  String title;
  String? description;

  /// Original file path (for reference, file may be deleted)
  String? originalFilePath;

  /// Source type: 'pdf', 'image', 'camera', 'text'
  String sourceType;

  /// Subject tag: 'math', 'science', 'history', 'english', 'other'
  String? subject;

  /// Grade level: 5-10
  int? gradeLevel;

  /// Processing status: 'pending', 'processing', 'completed', 'failed'
  String status;

  /// Error message if processing failed
  String? errorMessage;

  /// Timestamps
  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? processedAt;

  @Property(type: PropertyType.date)
  DateTime? lastAccessedAt;

  /// Total chunks generated from this material
  int chunkCount;

  // === Enhanced Metadata (Phase 1) ===

  /// Processing mode used: 'fast' or 'thorough'
  /// 'fast' = Syncfusion text extraction
  /// 'thorough' = Gemma Vision OCR
  String processingMode;

  /// Number of pages in source document
  int pageCount;

  /// Overall extraction quality score (0.0 to 1.0)
  /// Based on text density, OCR confidence, etc.
  double extractionQuality;

  /// File hash for duplicate detection (MD5 or similar)
  String? fileHash;

  /// Original file size in bytes
  int? fileSizeBytes;

  /// Total tokens across all chunks (for context budget estimation)
  int totalTokens;

  /// Total words across all chunks
  int totalWords;

  /// Detected language (ISO 639-1 code, e.g., 'en', 'hi')
  String? language;

  /// Detected topics as JSON array: ["algebra", "equations", "variables"]
  String? detectedTopicsJson;

  /// Extracted keywords as JSON array: ["solve", "x", "equation"]
  String? keywordsJson;

  Material({
    required this.title,
    this.description,
    this.originalFilePath,
    required this.sourceType,
    this.subject,
    this.gradeLevel,
    this.status = 'pending',
    this.errorMessage,
    DateTime? createdAt,
    this.processedAt,
    this.lastAccessedAt,
    this.chunkCount = 0,
    this.processingMode = 'fast',
    this.pageCount = 0,
    this.extractionQuality = 1.0,
    this.fileHash,
    this.fileSizeBytes,
    this.totalTokens = 0,
    this.totalWords = 0,
    this.language,
    this.detectedTopicsJson,
    this.keywordsJson,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if material was processed with vision/OCR
  bool get usedVisionProcessing => processingMode == 'thorough';

  /// Check if extraction quality is concerning
  bool get hasLowQuality => extractionQuality < 0.5;
}

