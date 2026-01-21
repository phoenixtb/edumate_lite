import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'inference_router.dart';
import '../entities/concept.dart';
import '../../stores/concept_store.dart';

/// LLM-based concept extraction for intelligent, semantic understanding
/// Uses on-device LLM to identify key concepts, entities, and relationships
class LLMConceptExtractor {
  final InferenceRouter _router;

  LLMConceptExtractor(this._router);

  static const _systemPrompt = '''You are an educational content analyzer. Extract key concepts from the given text.

Output ONLY valid JSON with this structure:
{
  "concepts": [
    {"name": "concept name", "type": "type", "importance": 1-5}
  ],
  "relationships": [
    {"from": "concept1", "to": "concept2", "relation": "relation_type"}
  ]
}

Concept types: definition, theorem, formula, principle, process, entity, term, event, person, place
Relation types: is_a, part_of, causes, requires, related_to, example_of, opposite_of

Rules:
- Extract 5-10 most important concepts
- Focus on domain-specific terms, not common words
- Identify hierarchical and causal relationships
- Rate importance 1-5 (5 = core concept, 1 = minor detail)
- Keep names concise (1-3 words)
- Output ONLY the JSON, no explanation''';

  /// Extract concepts from text using LLM
  /// Returns parsed concepts with types and importance scores
  Future<LLMExtractionResult> extractConcepts(String text) async {
    if (text.trim().isEmpty) {
      return LLMExtractionResult.empty();
    }

    // Limit text to avoid token limits
    final truncated = text.length > 2000 ? text.substring(0, 2000) : text;

    try {
      final buffer = StringBuffer();

      await for (final chunk in _router.generate(
        systemPrompt: _systemPrompt,
        context: '',
        query: truncated,
      )) {
        buffer.write(chunk);
      }

      final response = buffer.toString().trim();
      return _parseResponse(response);
    } catch (e) {
      return LLMExtractionResult.error('Extraction failed: $e');
    }
  }

  LLMExtractionResult _parseResponse(String response) {
    try {
      // Extract JSON from response (handle markdown code blocks)
      var jsonStr = response;
      if (response.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(response);
        if (match != null) {
          jsonStr = match.group(1)!.trim();
        }
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final concepts = <ExtractedConcept>[];
      final conceptsList = json['concepts'] as List<dynamic>? ?? [];
      
      for (final c in conceptsList) {
        if (c is Map<String, dynamic>) {
          concepts.add(ExtractedConcept(
            name: c['name']?.toString() ?? '',
            type: c['type']?.toString() ?? 'term',
            importance: (c['importance'] as num?)?.toInt() ?? 3,
          ));
        }
      }

      final relationships = <ExtractedRelationship>[];
      final relList = json['relationships'] as List<dynamic>? ?? [];
      
      for (final r in relList) {
        if (r is Map<String, dynamic>) {
          relationships.add(ExtractedRelationship(
            from: r['from']?.toString() ?? '',
            to: r['to']?.toString() ?? '',
            relation: r['relation']?.toString() ?? 'related_to',
          ));
        }
      }

      return LLMExtractionResult(
        concepts: concepts.where((c) => c.name.isNotEmpty).toList(),
        relationships: relationships.where((r) => r.from.isNotEmpty && r.to.isNotEmpty).toList(),
      );
    } catch (e) {
      return LLMExtractionResult.error('Parse failed: $e');
    }
  }

  /// Extract and store concepts for a material chunk
  /// Returns list of stored Concept entities
  Future<List<Concept>> extractAndStore({
    required String content,
    required int materialId,
    required int chunkId,
    String? subject,
  }) async {
    final result = await extractConcepts(content);
    if (result.hasError || result.concepts.isEmpty) {
      return [];
    }

    final conceptStore = GetIt.I<ConceptStore>();
    final storedConcepts = <Concept>[];

    // Store concepts
    for (final extracted in result.concepts) {
      final concept = conceptStore.findOrCreate(
        extracted.name,
        type: extracted.type,
        subject: subject,
      );
      concept.addMaterial(materialId);
      concept.addChunk(chunkId);
      // Store importance as part of frequency boost
      if (extracted.importance >= 4) {
        // High importance concepts get extra frequency
        concept.addMaterial(materialId); // Increment frequency
      }
      conceptStore.saveConcept(concept);
      storedConcepts.add(concept);
    }

    // Store relationships
    for (final rel in result.relationships) {
      final fromConcept = storedConcepts.firstWhere(
        (c) => c.name.toLowerCase() == rel.from.toLowerCase(),
        orElse: () => conceptStore.findOrCreate(rel.from, subject: subject),
      );
      final toConcept = storedConcepts.firstWhere(
        (c) => c.name.toLowerCase() == rel.to.toLowerCase(),
        orElse: () => conceptStore.findOrCreate(rel.to, subject: subject),
      );
      conceptStore.linkConcepts(fromConcept.id, toConcept.id);
    }

    return storedConcepts;
  }
}

/// Result of LLM concept extraction
class LLMExtractionResult {
  final List<ExtractedConcept> concepts;
  final List<ExtractedRelationship> relationships;
  final String? error;

  LLMExtractionResult({
    required this.concepts,
    required this.relationships,
    this.error,
  });

  factory LLMExtractionResult.empty() => LLMExtractionResult(
    concepts: [],
    relationships: [],
  );

  factory LLMExtractionResult.error(String message) => LLMExtractionResult(
    concepts: [],
    relationships: [],
    error: message,
  );

  bool get hasError => error != null;
  bool get isEmpty => concepts.isEmpty;
}

/// Extracted concept with metadata
class ExtractedConcept {
  final String name;
  final String type;
  final int importance; // 1-5

  ExtractedConcept({
    required this.name,
    required this.type,
    required this.importance,
  });
}

/// Extracted relationship between concepts
class ExtractedRelationship {
  final String from;
  final String to;
  final String relation;

  ExtractedRelationship({
    required this.from,
    required this.to,
    required this.relation,
  });
}
