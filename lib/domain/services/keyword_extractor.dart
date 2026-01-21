import 'dart:convert';

/// Extracts keywords and entities from text content
/// Uses rule-based extraction for speed (Phase 2)
/// Can be enhanced with LLM-based extraction later
class KeywordExtractor {
  KeywordExtractor._();
  static final KeywordExtractor instance = KeywordExtractor._();

  // Common stop words to filter out
  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'is', 'are', 'was', 'were',
    'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
    'will', 'would', 'could', 'should', 'may', 'might', 'must', 'shall',
    'can', 'need', 'dare', 'ought', 'used', 'to', 'of', 'in', 'for',
    'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
    'before', 'after', 'above', 'below', 'between', 'under', 'again',
    'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why',
    'how', 'all', 'each', 'few', 'more', 'most', 'other', 'some', 'such',
    'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too',
    'very', 's', 't', 'just', 'don', 'now', 'it', 'this', 'that',
    'these', 'those', 'i', 'me', 'my', 'myself', 'we', 'our', 'ours',
    'you', 'your', 'he', 'him', 'his', 'she', 'her', 'they', 'them',
    'what', 'which', 'who', 'whom', 'also', 'however', 'therefore',
    'thus', 'hence', 'although', 'because', 'since', 'while', 'if',
    'unless', 'until', 'about', 'against', 'along', 'among', 'around',
  };

  // Educational domain terms to prioritize
  static const _educationalTerms = {
    'definition', 'theorem', 'formula', 'equation', 'example', 'proof',
    'concept', 'principle', 'law', 'rule', 'hypothesis', 'theory',
    'experiment', 'result', 'conclusion', 'analysis', 'method', 'process',
    'function', 'variable', 'constant', 'factor', 'element', 'property',
    'solution', 'problem', 'answer', 'question', 'step', 'procedure',
    'diagram', 'figure', 'table', 'graph', 'chart', 'model',
    'cell', 'organism', 'species', 'evolution', 'gene', 'dna', 'protein',
    'energy', 'force', 'mass', 'velocity', 'acceleration', 'momentum',
    'atom', 'molecule', 'compound', 'reaction', 'bond', 'electron',
    'photosynthesis', 'respiration', 'mitosis', 'meiosis', 'ecosystem',
    'polynomial', 'quadratic', 'linear', 'derivative', 'integral',
    'fraction', 'ratio', 'proportion', 'percentage', 'probability',
  };

  /// Extract keywords from text
  /// Returns top N keywords sorted by importance
  List<String> extractKeywords(String text, {int maxKeywords = 10}) {
    if (text.isEmpty) return [];

    // Tokenize and clean
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();

    // Count frequencies
    final frequency = <String, int>{};
    for (final word in words) {
      frequency[word] = (frequency[word] ?? 0) + 1;
    }

    // Score keywords: frequency + educational term bonus
    final scored = frequency.entries.map((e) {
      var score = e.value.toDouble();
      if (_educationalTerms.contains(e.key)) {
        score *= 2.0; // Boost educational terms
      }
      // Boost longer words (likely more specific)
      if (e.key.length > 6) score *= 1.2;
      return MapEntry(e.key, score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(maxKeywords).map((e) => e.key).toList();
  }

  /// Extract named entities (simplified rule-based)
  /// Returns list of {name, type} maps
  List<Map<String, String>> extractEntities(String text) {
    final entities = <Map<String, String>>[];

    // Pattern: Definition of X / X is defined as
    final definitionPattern = RegExp(
      r'(?:definition\s+of\s+|(\w+)\s+is\s+defined\s+as)',
      caseSensitive: false,
    );
    for (final match in definitionPattern.allMatches(text)) {
      final term = match.group(1);
      if (term != null && term.length > 2) {
        entities.add({'name': term, 'type': 'definition'});
      }
    }

    // Pattern: Capitalized terms (potential named entities)
    final capitalPattern = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b');
    for (final match in capitalPattern.allMatches(text)) {
      final name = match.group(1)!;
      // Skip common words that are often capitalized
      if (!_isCommonCapitalized(name) && name.length > 2) {
        entities.add({'name': name, 'type': _guessEntityType(name)});
      }
    }

    // Deduplicate by normalized name
    final seen = <String>{};
    return entities.where((e) {
      final key = e['name']!.toLowerCase();
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// Extract concept tags from text
  /// These are broader topic categories
  List<String> extractConceptTags(String text, {int maxTags = 5}) {
    final lower = text.toLowerCase();

    // Check for subject-specific concept patterns
    final tags = <String>[];

    // Math concepts
    if (_hasMathConcept(lower)) {
      if (lower.contains('equation')) tags.add('equations');
      if (lower.contains('function')) tags.add('functions');
      if (lower.contains('graph')) tags.add('graphing');
      if (lower.contains('algebra')) tags.add('algebra');
      if (lower.contains('geometry')) tags.add('geometry');
      if (lower.contains('calculus') ||
          lower.contains('derivative') ||
          lower.contains('integral')) tags.add('calculus');
    }

    // Science concepts
    if (_hasScienceConcept(lower)) {
      if (lower.contains('cell')) tags.add('biology');
      if (lower.contains('atom') || lower.contains('molecule'))
        tags.add('chemistry');
      if (lower.contains('force') || lower.contains('energy'))
        tags.add('physics');
      if (lower.contains('evolution') || lower.contains('species'))
        tags.add('evolution');
      if (lower.contains('ecosystem') || lower.contains('environment'))
        tags.add('ecology');
    }

    // History concepts
    if (_hasHistoryConcept(lower)) {
      if (lower.contains('war')) tags.add('warfare');
      if (lower.contains('revolution')) tags.add('revolutions');
      if (lower.contains('civilization')) tags.add('civilizations');
    }

    return tags.take(maxTags).toList();
  }

  /// Convert keywords list to JSON string for storage
  String keywordsToJson(List<String> keywords) => jsonEncode(keywords);

  /// Convert entities list to JSON string for storage
  String entitiesToJson(List<Map<String, String>> entities) =>
      jsonEncode(entities);

  /// Parse keywords from JSON string
  List<String> keywordsFromJson(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(json));
    } catch (_) {
      return [];
    }
  }

  /// Parse entities from JSON string
  List<Map<String, String>> entitiesFromJson(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return List<Map<String, String>>.from(
        (jsonDecode(json) as List).map((e) => Map<String, String>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  bool _isCommonCapitalized(String name) {
    const common = {
      'The', 'A', 'An', 'In', 'On', 'At', 'To', 'For', 'Of', 'And', 'Or',
      'But', 'Is', 'Are', 'Was', 'Were', 'This', 'That', 'These', 'Those',
      'Chapter', 'Section', 'Figure', 'Table', 'Example', 'Step', 'Page',
    };
    return common.contains(name);
  }

  String _guessEntityType(String name) {
    // Simple heuristics for entity type
    if (name.contains('Law') || name.contains('Theorem')) return 'theorem';
    if (name.contains('Equation') || name.contains('Formula')) return 'formula';
    // Default to person for capitalized names
    return 'person';
  }

  bool _hasMathConcept(String text) {
    return text.contains('equation') ||
        text.contains('solve') ||
        text.contains('calculate') ||
        text.contains('formula') ||
        text.contains('variable') ||
        text.contains('function');
  }

  bool _hasScienceConcept(String text) {
    return text.contains('cell') ||
        text.contains('atom') ||
        text.contains('energy') ||
        text.contains('force') ||
        text.contains('organism') ||
        text.contains('experiment');
  }

  bool _hasHistoryConcept(String text) {
    return text.contains('century') ||
        text.contains('war') ||
        text.contains('empire') ||
        text.contains('civilization') ||
        text.contains('revolution');
  }

  /// Extract concept relationships from text
  /// Returns list of {from, to, relation} maps
  /// e.g., {"from": "mitosis", "to": "cell division", "relation": "is_a"}
  List<Map<String, String>> extractRelationships(String text) {
    final relationships = <Map<String, String>>[];
    final lower = text.toLowerCase();

    // Pattern: "X is a type of Y" / "X is a kind of Y"
    final isAPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+is\s+(?:a\s+)?(?:type|kind|form)\s+of\s+(\w+(?:\s+\w+)?)',
      caseSensitive: false,
    );
    for (final match in isAPattern.allMatches(lower)) {
      relationships.add({
        'from': match.group(1)!.trim(),
        'to': match.group(2)!.trim(),
        'relation': 'is_a',
      });
    }

    // Pattern: "X includes/contains Y"
    final containsPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+(?:includes?|contains?)\s+(\w+(?:\s+\w+)?)',
      caseSensitive: false,
    );
    for (final match in containsPattern.allMatches(lower)) {
      relationships.add({
        'from': match.group(1)!.trim(),
        'to': match.group(2)!.trim(),
        'relation': 'contains',
      });
    }

    // Pattern: "X is part of Y"
    final partOfPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+is\s+(?:a\s+)?part\s+of\s+(\w+(?:\s+\w+)?)',
      caseSensitive: false,
    );
    for (final match in partOfPattern.allMatches(lower)) {
      relationships.add({
        'from': match.group(1)!.trim(),
        'to': match.group(2)!.trim(),
        'relation': 'part_of',
      });
    }

    // Pattern: "X causes/leads to Y"
    final causesPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+(?:causes?|leads?\s+to|results?\s+in)\s+(\w+(?:\s+\w+)?)',
      caseSensitive: false,
    );
    for (final match in causesPattern.allMatches(lower)) {
      relationships.add({
        'from': match.group(1)!.trim(),
        'to': match.group(2)!.trim(),
        'relation': 'causes',
      });
    }

    // Pattern: "X is related to Y" / "X relates to Y"
    final relatedPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+(?:is\s+)?related\s+to\s+(\w+(?:\s+\w+)?)',
      caseSensitive: false,
    );
    for (final match in relatedPattern.allMatches(lower)) {
      relationships.add({
        'from': match.group(1)!.trim(),
        'to': match.group(2)!.trim(),
        'relation': 'related_to',
      });
    }

    // Pattern: "X requires/needs Y"
    final requiresPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+(?:requires?|needs?)\s+(\w+(?:\s+\w+)?)',
      caseSensitive: false,
    );
    for (final match in requiresPattern.allMatches(lower)) {
      relationships.add({
        'from': match.group(1)!.trim(),
        'to': match.group(2)!.trim(),
        'relation': 'requires',
      });
    }

    // Deduplicate
    final seen = <String>{};
    return relationships.where((r) {
      final key = '${r['from']}-${r['relation']}-${r['to']}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// Convert relationships to JSON string
  String relationshipsToJson(List<Map<String, String>> relationships) =>
      jsonEncode(relationships);

  /// Parse relationships from JSON
  List<Map<String, String>> relationshipsFromJson(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return List<Map<String, String>>.from(
        (jsonDecode(json) as List).map((e) => Map<String, String>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }
}
