import 'package:objectbox/objectbox.dart';
import 'dart:convert';

/// Represents an extracted concept/term across materials
/// Used for knowledge graph, concept-based search, and related content
@Entity()
class Concept {
  @Id()
  int id = 0;

  /// Display name of the concept
  String name;

  /// Normalized name for matching (lowercase, trimmed)
  @Index()
  String normalizedName;

  /// Concept type for categorization
  /// 'term', 'person', 'formula', 'theorem', 'concept', 'event', 'place', 'definition'
  String type;

  /// Definition (extracted or LLM-generated)
  String? definition;

  /// Material IDs where this concept appears (JSON array)
  /// e.g., "[1, 2, 5]"
  String materialIdsJson;

  /// Chunk IDs where this concept appears (JSON array)
  /// e.g., "[10, 11, 25, 30]"
  String chunkIdsJson;

  /// Total occurrences across all materials
  int frequency;

  /// Related concept IDs (JSON array)
  /// For building knowledge graph
  String? relatedConceptIdsJson;

  /// Subject area: 'math', 'science', 'history', 'english', 'general'
  String? subject;

  /// Importance score based on frequency and context (0.0 to 1.0)
  double importance;

  /// Timestamps
  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? updatedAt;

  Concept({
    required this.name,
    String? normalizedName,
    this.type = 'term',
    this.definition,
    this.materialIdsJson = '[]',
    this.chunkIdsJson = '[]',
    this.frequency = 1,
    this.relatedConceptIdsJson,
    this.subject,
    this.importance = 0.5,
    DateTime? createdAt,
    this.updatedAt,
  })  : normalizedName = normalizedName ?? _normalize(name),
        createdAt = createdAt ?? DateTime.now();

  /// Normalize a name for matching
  static String _normalize(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Get material IDs as list
  List<int> get materialIds {
    try {
      return List<int>.from(jsonDecode(materialIdsJson));
    } catch (_) {
      return [];
    }
  }

  /// Set material IDs from list
  set materialIds(List<int> ids) {
    materialIdsJson = jsonEncode(ids);
  }

  /// Get chunk IDs as list
  List<int> get chunkIds {
    try {
      return List<int>.from(jsonDecode(chunkIdsJson));
    } catch (_) {
      return [];
    }
  }

  /// Set chunk IDs from list
  set chunkIds(List<int> ids) {
    chunkIdsJson = jsonEncode(ids);
  }

  /// Get related concept IDs as list
  List<int> get relatedConceptIds {
    if (relatedConceptIdsJson == null) return [];
    try {
      return List<int>.from(jsonDecode(relatedConceptIdsJson!));
    } catch (_) {
      return [];
    }
  }

  /// Set related concept IDs from list
  set relatedConceptIds(List<int> ids) {
    relatedConceptIdsJson = jsonEncode(ids);
  }

  /// Add a material reference
  void addMaterial(int materialId) {
    final ids = materialIds;
    if (!ids.contains(materialId)) {
      ids.add(materialId);
      materialIds = ids;
      frequency++;
      updatedAt = DateTime.now();
    }
  }

  /// Add a chunk reference
  void addChunk(int chunkId) {
    final ids = chunkIds;
    if (!ids.contains(chunkId)) {
      ids.add(chunkId);
      chunkIds = ids;
    }
  }

  /// Check if concept appears in a material
  bool appearsInMaterial(int materialId) => materialIds.contains(materialId);
}
