import 'package:objectbox/objectbox.dart';
import 'material.dart';

/// Represents a chunk of text extracted from a material
@Entity()
class Chunk {
  @Id()
  int id = 0;

  /// Reference to parent material
  final material = ToOne<Material>();

  /// The actual text content
  String content;

  /// Vector embedding for HNSW search
  @HnswIndex(dimensions: 768, neighborsPerNode: 30, indexingSearchCount: 200)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  /// Position in original document (page number, section, etc.)
  int? pageNumber;
  int? sectionIndex;

  /// Chunk sequence within the material
  int sequenceIndex;

  /// Chunk type: 'paragraph', 'heading', 'list', 'table', 'equation', 'definition', 'example'
  String chunkType;

  /// Word count for filtering
  int wordCount;

  /// Metadata as JSON string (legacy, prefer specific fields below)
  String? metadataJson;

  // === Enhanced Metadata (Phase 1) ===

  /// Actual token count from tokenizer (more accurate than word count)
  int tokenCount;

  /// Confidence score for this chunk (0.0 to 1.0)
  /// High for clean text extraction, lower for OCR with uncertainty
  double confidenceScore;

  /// How this chunk was extracted
  /// 'text' = Syncfusion programmatic extraction
  /// 'vision' = Gemma Vision OCR
  String extractionMethod;

  /// Character offset in original page text (for source highlighting)
  int? startOffset;
  int? endOffset;

  /// Importance score for quiz/summary generation (0.0 to 1.0)
  /// Based on chunk type, position, content analysis
  double importance;

  /// Whether this chunk contains a key point/concept
  /// Used for quiz generation and study guides
  bool isKeyPoint;

  /// Extracted keywords as JSON array: ["solve", "equation", "variable"]
  String? keywordsJson;

  /// Extracted entities as JSON array: [{"name": "Pythagoras", "type": "person"}]
  String? entitiesJson;

  /// Concept tags for semantic linking: ["algebra", "linear-equations"]
  String? conceptTagsJson;

  /// Parent chunk ID for hierarchical structure (e.g., paragraph under heading)
  int? parentChunkId;

  /// Related chunk IDs as JSON array for cross-references
  String? relatedChunkIdsJson;

  /// Sentence count for readability estimation
  int sentenceCount;

  Chunk({
    required this.content,
    this.embedding,
    this.pageNumber,
    this.sectionIndex,
    required this.sequenceIndex,
    this.chunkType = 'paragraph',
    int? wordCount,
    this.metadataJson,
    this.tokenCount = 0,
    this.confidenceScore = 1.0,
    this.extractionMethod = 'text',
    this.startOffset,
    this.endOffset,
    this.importance = 0.5,
    this.isKeyPoint = false,
    this.keywordsJson,
    this.entitiesJson,
    this.conceptTagsJson,
    this.parentChunkId,
    this.relatedChunkIdsJson,
    int? sentenceCount,
  })  : wordCount = wordCount ??
            content.split(' ').where((w) => w.isNotEmpty).length,
        sentenceCount = sentenceCount ??
            content.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length;

  /// Check if this chunk has high confidence extraction
  bool get hasHighConfidence => confidenceScore >= 0.8;

  /// Check if this chunk was extracted via OCR
  bool get wasOcrExtracted => extractionMethod == 'vision';
}

