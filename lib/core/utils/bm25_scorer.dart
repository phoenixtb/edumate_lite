import 'dart:math';

/// BM25 (Best Matching 25) scoring for keyword-based retrieval
/// Combines term frequency, inverse document frequency, and document length normalization
class BM25Scorer {
  /// BM25 parameters
  static const double k1 = 1.5; // Term frequency saturation
  static const double b = 0.75; // Document length normalization

  /// Calculate BM25 score for a query against a document
  /// 
  /// [query] - Search query string
  /// [document] - Document text to score
  /// [avgDocLength] - Average document length in corpus (for normalization)
  /// [documentFrequencies] - Map of term -> number of documents containing term
  /// [totalDocuments] - Total number of documents in corpus
  static double score({
    required String query,
    required String document,
    required double avgDocLength,
    required Map<String, int> documentFrequencies,
    required int totalDocuments,
  }) {
    final queryTerms = _tokenize(query);
    final docTerms = _tokenize(document);
    final docLength = docTerms.length;

    if (docLength == 0 || queryTerms.isEmpty) return 0.0;

    // Count term frequencies in document
    final termFreq = <String, int>{};
    for (final term in docTerms) {
      termFreq[term] = (termFreq[term] ?? 0) + 1;
    }

    double totalScore = 0.0;

    for (final term in queryTerms) {
      final tf = termFreq[term] ?? 0;
      if (tf == 0) continue;

      // IDF: log((N - n + 0.5) / (n + 0.5) + 1)
      final docFreq = documentFrequencies[term] ?? 0;
      final idf = log((totalDocuments - docFreq + 0.5) / (docFreq + 0.5) + 1);

      // BM25 term score
      final numerator = tf * (k1 + 1);
      final denominator = tf + k1 * (1 - b + b * (docLength / avgDocLength));
      
      totalScore += idf * (numerator / denominator);
    }

    return totalScore;
  }

  /// Simplified BM25 score without corpus statistics
  /// Uses only term frequency and document length normalization
  /// Good for single-query ranking when corpus stats aren't available
  static double scoreSimple({
    required String query,
    required String document,
    double avgDocLength = 500.0, // Reasonable default for chunks
  }) {
    final queryTerms = _tokenize(query);
    final docTerms = _tokenize(document);
    final docLength = docTerms.length;

    if (docLength == 0 || queryTerms.isEmpty) return 0.0;

    // Count term frequencies
    final termFreq = <String, int>{};
    for (final term in docTerms) {
      termFreq[term] = (termFreq[term] ?? 0) + 1;
    }

    double totalScore = 0.0;
    // ignore: unused_local_variable
    int matchedTerms = 0; // Track for debugging if needed

    for (final term in queryTerms) {
      final tf = termFreq[term] ?? 0;
      if (tf == 0) {
        // Check for partial matches (stemming approximation)
        for (final docTerm in termFreq.keys) {
          if (docTerm.startsWith(term) || term.startsWith(docTerm)) {
            matchedTerms++;
            final partialTf = termFreq[docTerm]!;
            final numerator = partialTf * (k1 + 1);
            final denominator = partialTf + k1 * (1 - b + b * (docLength / avgDocLength));
            totalScore += 0.5 * (numerator / denominator); // Partial match weight
            break;
          }
        }
        continue;
      }

      matchedTerms++;

      // Simplified IDF approximation (assumes term appears in ~10% of docs)
      const idf = 2.3; // log(10) ≈ 2.3

      final numerator = tf * (k1 + 1);
      final denominator = tf + k1 * (1 - b + b * (docLength / avgDocLength));
      
      totalScore += idf * (numerator / denominator);
    }

    // Normalize by query length to get 0-1 range
    if (queryTerms.isNotEmpty) {
      totalScore = totalScore / (queryTerms.length * 3.0); // Max ~3 per term
    }

    return totalScore.clamp(0.0, 1.0);
  }

  /// Tokenize text into lowercase terms, removing stop words
  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2 && !_stopWords.contains(t))
        .toList();
  }

  static const _stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
    'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by',
    'from', 'as', 'into', 'through', 'during', 'before', 'after', 'above',
    'below', 'between', 'under', 'again', 'further', 'then', 'once',
    'what', 'which', 'who', 'whom', 'this', 'that', 'these', 'those',
    'and', 'but', 'if', 'or', 'because', 'until', 'while', 'about',
    'how', 'why', 'when', 'where', 'please', 'explain', 'tell', 'me',
    'you', 'briefly', 'describe', 'give', 'show',
  };
}
