import 'package:mobx/mobx.dart';
import '../domain/entities/concept.dart';
import '../domain/services/keyword_extractor.dart';
import '../infrastructure/database/objectbox.dart';
import '../objectbox.g.dart' hide Store;

part 'concept_store.g.dart';

/// MobX store for managing concepts
class ConceptStore = _ConceptStore with _$ConceptStore;

abstract class _ConceptStore with Store {
  final ObjectBoxManager _objectBox;

  _ConceptStore(this._objectBox);

  @observable
  ObservableList<Concept> concepts = ObservableList<Concept>();

  @observable
  bool isLoading = false;

  @observable
  String? error;

  @computed
  int get conceptCount => concepts.length;

  /// Load all concepts from database
  @action
  Future<void> loadConcepts() async {
    isLoading = true;
    error = null;

    try {
      final query = _objectBox.conceptBox
          .query()
          .order(Concept_.frequency, flags: Order.descending)
          .build();
      final loaded = query.find();
      query.close();
      concepts = ObservableList.of(loaded);
    } catch (e) {
      error = 'Failed to load concepts: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Get concept count directly from database
  int getConceptCountFromDb() {
    return _objectBox.conceptBox.count();
  }

  /// Find or create a concept by name
  @action
  Concept findOrCreate(String name, {String type = 'term', String? subject}) {
    final normalized = name.toLowerCase().trim();

    // Try to find existing
    final query = _objectBox.conceptBox
        .query(Concept_.normalizedName.equals(normalized))
        .build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      return existing;
    }

    // Create new
    final concept = Concept(
      name: name,
      type: type,
      subject: subject,
    );
    concept.id = _objectBox.conceptBox.put(concept);
    concepts.add(concept);
    return concept;
  }

  /// Save/update a concept to database
  @action
  void saveConcept(Concept concept) {
    _objectBox.conceptBox.put(concept);
    
    // Update local list
    final index = concepts.indexWhere((c) => c.id == concept.id);
    if (index >= 0) {
      concepts[index] = concept;
    } else {
      concepts.add(concept);
    }
  }

  /// Add material reference to a concept
  @action
  void addMaterialToConcept(int conceptId, int materialId, int chunkId) {
    final concept = _objectBox.conceptBox.get(conceptId);
    if (concept == null) return;

    concept.addMaterial(materialId);
    concept.addChunk(chunkId);
    _objectBox.conceptBox.put(concept);

    // Update local list
    final index = concepts.indexWhere((c) => c.id == conceptId);
    if (index >= 0) {
      concepts[index] = concept;
    }
  }

  /// Get concepts for a material - queries database directly
  /// Excludes keyword-based concepts (type='keyword')
  @action
  List<Concept> getConceptsForMaterial(int materialId) {
    // Query database directly to ensure we get all concepts
    final allConcepts = _objectBox.conceptBox.getAll();
    final materialConcepts = allConcepts
        .where((c) => c.appearsInMaterial(materialId) && c.type != 'keyword')
        .toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    return materialConcepts;
  }
  
  /// Check if a material has LLM-extracted concepts (not keyword-based)
  bool hasLLMConcepts(int materialId) {
    final allConcepts = _objectBox.conceptBox.getAll();
    return allConcepts.any(
      (c) => c.appearsInMaterial(materialId) && c.type != 'keyword',
    );
  }

  /// Get top concepts by frequency
  @action
  List<Concept> getTopConcepts({int limit = 20}) {
    final sorted = List<Concept>.from(concepts)
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    return sorted.take(limit).toList();
  }

  /// Search concepts by name
  @action
  List<Concept> searchConcepts(String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return [];

    return concepts
        .where((c) => c.normalizedName.contains(normalized))
        .toList();
  }

  /// Get related concepts (concepts that appear in same materials)
  @action
  List<Concept> getRelatedConcepts(int conceptId, {int limit = 5}) {
    final concept = concepts.firstWhere(
      (c) => c.id == conceptId,
      orElse: () => Concept(name: ''),
    );
    if (concept.id == 0) return [];

    final materialIds = concept.materialIds;
    if (materialIds.isEmpty) return [];

    // Find concepts that share materials
    final related = concepts
        .where((c) =>
            c.id != conceptId &&
            c.materialIds.any((m) => materialIds.contains(m)))
        .toList()
      ..sort((a, b) {
        // Sort by number of shared materials
        final aShared =
            a.materialIds.where((m) => materialIds.contains(m)).length;
        final bShared =
            b.materialIds.where((m) => materialIds.contains(m)).length;
        return bShared.compareTo(aShared);
      });

    return related.take(limit).toList();
  }

  /// Delete concept
  @action
  void deleteConcept(int conceptId) {
    _objectBox.conceptBox.remove(conceptId);
    concepts.removeWhere((c) => c.id == conceptId);
  }

  /// Clear all concepts (for testing/reset)
  @action
  void clearAll() {
    _objectBox.conceptBox.removeAll();
    concepts.clear();
  }

  /// Extract and store concepts from chunk content using keyword extraction
  /// 
  /// @deprecated Use LLMConceptExtractor for semantic concept extraction.
  /// This keyword-based extraction creates lower-quality concepts.
  /// Only use as fallback when LLM is not available.
  @action
  List<Concept> extractAndStoreConcepts({
    required String content,
    required int materialId,
    required int chunkId,
    String? subject,
  }) {
    final keywords = KeywordExtractor.instance.extractKeywords(
      content,
      maxKeywords: 5,
    );

    final storedConcepts = <Concept>[];

    for (final keyword in keywords) {
      final concept = findOrCreate(keyword, type: 'keyword', subject: subject);
      concept.addMaterial(materialId);
      concept.addChunk(chunkId);
      _objectBox.conceptBox.put(concept);
      storedConcepts.add(concept);
    }

    // Extract and store concept relationships
    final relationships = KeywordExtractor.instance.extractRelationships(content);
    for (final rel in relationships) {
      final fromName = rel['from']!;
      final toName = rel['to']!;

      // Only link if both concepts exist or are keywords
      if (keywords.contains(fromName) || keywords.contains(toName)) {
        final fromConcept = findOrCreate(fromName, type: 'keyword', subject: subject);
        final toConcept = findOrCreate(toName, type: 'keyword', subject: subject);

        // Add bidirectional relationship
        linkConcepts(fromConcept.id, toConcept.id);
      }
    }

    return storedConcepts;
  }

  /// Link two concepts as related
  @action
  void linkConcepts(int conceptId1, int conceptId2) {
    if (conceptId1 == conceptId2) return;

    final concept1 = _objectBox.conceptBox.get(conceptId1);
    final concept2 = _objectBox.conceptBox.get(conceptId2);

    if (concept1 == null || concept2 == null) return;

    // Add bidirectional relationship
    final related1 = concept1.relatedConceptIds;
    if (!related1.contains(conceptId2)) {
      related1.add(conceptId2);
      concept1.relatedConceptIds = related1;
      _objectBox.conceptBox.put(concept1);
    }

    final related2 = concept2.relatedConceptIds;
    if (!related2.contains(conceptId1)) {
      related2.add(conceptId1);
      concept2.relatedConceptIds = related2;
      _objectBox.conceptBox.put(concept2);
    }

    // Update local list
    final idx1 = concepts.indexWhere((c) => c.id == conceptId1);
    if (idx1 >= 0) concepts[idx1] = concept1;
    final idx2 = concepts.indexWhere((c) => c.id == conceptId2);
    if (idx2 >= 0) concepts[idx2] = concept2;
  }

  /// Get explicitly linked concepts (from relationship extraction)
  List<Concept> getLinkedConcepts(int conceptId) {
    final concept = concepts.firstWhere(
      (c) => c.id == conceptId,
      orElse: () => Concept(name: ''),
    );
    if (concept.id == 0) return [];

    final relatedIds = concept.relatedConceptIds;
    return concepts.where((c) => relatedIds.contains(c.id)).toList();
  }

  /// Re-extract concepts for an existing material from its chunks
  /// Use this for materials processed before concept extraction was added
  @action
  Future<int> reextractConceptsForMaterial({
    required int materialId,
    required List<String> chunkContents,
    required List<int> chunkIds,
    String? subject,
  }) async {
    int totalConcepts = 0;

    for (var i = 0; i < chunkContents.length; i++) {
      final content = chunkContents[i];
      final chunkId = chunkIds[i];

      final extracted = extractAndStoreConcepts(
        content: content,
        materialId: materialId,
        chunkId: chunkId,
        subject: subject,
      );
      totalConcepts += extracted.length;
    }

    // Reload concepts to update local list
    await loadConcepts();

    return totalConcepts;
  }
}
