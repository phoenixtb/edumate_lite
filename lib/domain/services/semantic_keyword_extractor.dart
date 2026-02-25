import 'dart:io';
import 'dart:math' as math;
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import '../interfaces/embedding_provider.dart';
import '../../infrastructure/ai/gemma_embedding_provider.dart';
import '../../core/utils/logger.dart';

/// File logger for debugging semantic keyword extraction
class _FileLogger {
  static File? _logFile;
  static bool _initialized = false;
  
  static Future<void> _init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/ske_debug.log');
      await _logFile!.writeAsString('=== SKE Debug Log ===\n${DateTime.now()}\n\n');
      _initialized = true;
    } catch (e) {
      AppLogger.error('Failed to init file logger', e);
    }
  }
  
  static Future<void> log(String msg) async {
    await _init();
    try {
      await _logFile?.writeAsString('$msg\n', mode: FileMode.append);
    } catch (_) {}
    AppLogger.debug(msg);
  }
  
  static String? get path => _logFile?.path;
}

/// KeyBERT-style semantic keyword extraction using embeddings
/// 
/// Algorithm:
/// 1. Extract candidate n-grams (1-3 words)
/// 2. Embed the full document
/// 3. Embed each candidate phrase
/// 4. Compute cosine similarity between candidates and document
/// 5. Use MMR (Maximal Marginal Relevance) for diversity
/// 6. Return top-k keywords
class SemanticKeywordExtractor {
  final EmbeddingProvider _embeddingProvider;
  
  SemanticKeywordExtractor(this._embeddingProvider);
  
  /// Get instance from service locator
  static SemanticKeywordExtractor get instance {
    // GetIt has the concrete GemmaEmbeddingProvider registered
    return SemanticKeywordExtractor(GetIt.I<GemmaEmbeddingProvider>());
  }

  // Stop words to filter out
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
    'find', 'finding', 'found', 'give', 'given', 'get', 'getting',
    'make', 'making', 'made', 'take', 'taking', 'took', 'use', 'using',
    'see', 'seeing', 'saw', 'know', 'knowing', 'knew', 'think', 'thought',
    'want', 'wanted', 'look', 'looking', 'looked', 'come', 'coming', 'came',
    'go', 'going', 'went', 'say', 'said', 'tell', 'told', 'ask', 'asked',
    'work', 'working', 'try', 'trying', 'call', 'called', 'needed',
    'feel', 'feeling', 'become', 'became', 'leave', 'left', 'put', 'mean',
    'keep', 'let', 'begin', 'seem', 'help', 'show', 'hear', 'play', 'run',
    'move', 'live', 'believe', 'hold', 'bring', 'happen', 'write', 'provide',
    'sit', 'stand', 'lose', 'pay', 'meet', 'include', 'continue', 'set',
    'learn', 'change', 'lead', 'understand', 'watch', 'follow', 'stop',
    'create', 'speak', 'read', 'allow', 'add', 'spend', 'grow', 'open',
    'walk', 'win', 'offer', 'remember', 'love', 'consider', 'appear',
    'buy', 'wait', 'serve', 'die', 'send', 'expect', 'build', 'stay',
    'fall', 'cut', 'reach', 'kill', 'remain', 'example', 'following',
  };

  /// Extract semantic keywords from text using embedding similarity
  /// 
  /// [text] - Input document text
  /// [maxKeywords] - Maximum number of keywords to return
  /// [ngramRange] - Tuple of (min, max) n-gram sizes, e.g., (1, 3) for 1-3 word phrases
  /// [diversityWeight] - MMR diversity weight (0.0 = pure similarity, 1.0 = max diversity)
  Future<List<SemanticKeyword>> extractKeywords(
    String text, {
    int maxKeywords = 10,
    (int, int) ngramRange = (1, 3),
    double diversityWeight = 0.3,
  }) async {
    await _FileLogger.log('=== Extraction Start ===');
    await _FileLogger.log('Text length: ${text.length}');
    
    // Fix spaced text and log
    final fixedText = _fixSpacedText(text);
    final wasFixed = fixedText != text;
    await _FileLogger.log('Spaced text fix applied: $wasFixed');
    await _FileLogger.log('Fixed text first 300 chars: ${fixedText.length > 300 ? fixedText.substring(0, 300) : fixedText}');
    
    if (text.isEmpty) {
      await _FileLogger.log('ERROR: Empty text');
      return [];
    }
    
    if (!_embeddingProvider.isReady) {
      await _FileLogger.log('ERROR: Embedding provider not ready');
      return [];
    }

    try {
      // 1. Extract candidate n-grams (uses fixed text internally)
      final candidates = await _extractCandidatesWithLog(fixedText, ngramRange);
      await _FileLogger.log('Extracted ${candidates.length} candidates');
      
      if (candidates.isEmpty) {
        await _FileLogger.log('WARNING: No candidates extracted');
        return [];
      }

      await _FileLogger.log('Top 20 candidates: ${candidates.take(20).join(", ")}');

      // Limit candidates to avoid excessive embedding calls
      final limitedCandidates = candidates.take(100).toList();

      // 2. Embed the fixed document (truncate for embedding if too long)
      final docText = fixedText.length > 2000 ? fixedText.substring(0, 2000) : fixedText;
      final docEmbedding = await _embeddingProvider.embed(docText);
      await _FileLogger.log('Doc embedding dim: ${docEmbedding.length}');

      // 3. Embed all candidates in batch
      final candidateEmbeddings = await _embeddingProvider.embedBatch(
        limitedCandidates,
      );
      await _FileLogger.log('Got ${candidateEmbeddings.length} candidate embeddings');

      // 4. Calculate similarities
      final scored = <_ScoredCandidate>[];
      for (var i = 0; i < limitedCandidates.length; i++) {
        final similarity = _cosineSimilarity(docEmbedding, candidateEmbeddings[i]);
        scored.add(_ScoredCandidate(
          text: limitedCandidates[i],
          embedding: candidateEmbeddings[i],
          similarity: similarity,
        ));
      }

      // Sort by similarity and log top 15
      scored.sort((a, b) => b.similarity.compareTo(a.similarity));
      await _FileLogger.log('Top 15 by similarity:');
      for (var i = 0; i < math.min(15, scored.length); i++) {
        await _FileLogger.log('  ${i + 1}. "${scored[i].text}" -> ${(scored[i].similarity * 100).toStringAsFixed(1)}%');
      }

      // 5. Apply MMR for diversity
      final selected = _maximalMarginalRelevance(
        scored,
        docEmbedding,
        maxKeywords,
        diversityWeight,
      );

      await _FileLogger.log('Final selection: ${selected.map((s) => s.keyword).join(", ")}');
      await _FileLogger.log('Log file: ${_FileLogger.path}');
      return selected;
    } catch (e, st) {
      await _FileLogger.log('ERROR: $e\n$st');
      return [];
    }
  }
  
  /// Extract candidates with file logging
  Future<List<String>> _extractCandidatesWithLog(String text, (int, int) ngramRange) async {
    final result = _extractCandidates(text, ngramRange);
    return result;
  }

  /// Detect and fix spaced-out text (e.g., "H e l l o" -> "Hello")
  /// This happens with some PDF extractors
  String _fixSpacedText(String text) {
    // Check if text looks like it has char-by-char spacing
    // Pattern: single chars separated by spaces, like "H e l l o  W o r l d"
    final spacedPattern = RegExp(r'^([A-Za-z] ){3,}');
    if (!spacedPattern.hasMatch(text.trim())) {
      return text; // Not spaced text
    }
    
    // Fix: remove spaces between single characters
    // "H e l l o  W o r l d" -> "Hello World"
    final buffer = StringBuffer();
    final chars = text.split('');
    
    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      
      if (char == ' ') {
        // Check if this is a single-char separator or a real word break
        // Real word break: double space "  "
        final next = i < chars.length - 1 ? chars[i + 1] : '';
        
        // Double space = word break
        if (next == ' ') {
          buffer.write(' ');
          i++; // Skip the next space
        }
        // Otherwise skip the space (it's between chars)
      } else {
        buffer.write(char);
      }
    }
    
    return buffer.toString();
  }

  /// Extract candidate n-grams from text
  List<String> _extractCandidates(String text, (int, int) ngramRange) {
    final (minN, maxN) = ngramRange;
    final candidates = <String>{};

    // Fix spaced-out text from PDF extraction
    final fixedText = _fixSpacedText(text);

    // Tokenize: split on whitespace and punctuation
    final words = fixedText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();

    // Generate n-grams
    for (var n = minN; n <= maxN; n++) {
      for (var i = 0; i <= words.length - n; i++) {
        final ngram = words.sublist(i, i + n).join(' ');
        
        // Filter: skip if all words are stop words
        final ngramWords = ngram.split(' ');
        if (ngramWords.every((w) => _stopWords.contains(w))) continue;
        
        // Filter: skip if starts or ends with stop word (for multi-word)
        if (n > 1) {
          if (_stopWords.contains(ngramWords.first) || 
              _stopWords.contains(ngramWords.last)) continue;
        }
        
        // Filter: skip very short single words
        if (n == 1 && ngram.length < 4) continue;
        
        candidates.add(ngram);
      }
    }

    // Sort by frequency in text (more frequent = earlier in list)
    final frequency = <String, int>{};
    for (final c in candidates) {
      frequency[c] = RegExp(RegExp.escape(c), caseSensitive: false)
          .allMatches(text)
          .length;
    }

    final sorted = candidates.toList()
      ..sort((a, b) => (frequency[b] ?? 0).compareTo(frequency[a] ?? 0));

    return sorted;
  }

  /// Compute cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Maximal Marginal Relevance for diverse keyword selection
  /// 
  /// MMR = λ * sim(candidate, doc) - (1-λ) * max(sim(candidate, selected))
  List<SemanticKeyword> _maximalMarginalRelevance(
    List<_ScoredCandidate> candidates,
    List<double> docEmbedding,
    int topK,
    double diversityWeight,
  ) {
    if (candidates.isEmpty) return [];

    final selected = <SemanticKeyword>[];
    final remaining = List<_ScoredCandidate>.from(candidates);

    // Sort by similarity first
    remaining.sort((a, b) => b.similarity.compareTo(a.similarity));

    // Select first (most similar to doc)
    final first = remaining.removeAt(0);
    selected.add(SemanticKeyword(
      keyword: first.text,
      score: first.similarity,
    ));

    // Iteratively select based on MMR
    while (selected.length < topK && remaining.isNotEmpty) {
      double bestScore = double.negativeInfinity;
      int bestIdx = 0;

      for (var i = 0; i < remaining.length; i++) {
        final candidate = remaining[i];

        // Find max similarity to already selected keywords
        double maxSimToSelected = 0.0;
        for (final s in selected) {
          // Find the embedding for this selected keyword
          final selectedEmb = candidates
              .firstWhere((c) => c.text == s.keyword)
              .embedding;
          final sim = _cosineSimilarity(candidate.embedding, selectedEmb);
          if (sim > maxSimToSelected) maxSimToSelected = sim;
        }

        // MMR score
        final mmrScore = (1 - diversityWeight) * candidate.similarity -
            diversityWeight * maxSimToSelected;

        if (mmrScore > bestScore) {
          bestScore = mmrScore;
          bestIdx = i;
        }
      }

      final chosen = remaining.removeAt(bestIdx);
      selected.add(SemanticKeyword(
        keyword: chosen.text,
        score: chosen.similarity,
      ));
    }

    return selected;
  }
}

/// A keyword with its semantic similarity score
class SemanticKeyword {
  final String keyword;
  final double score;

  SemanticKeyword({required this.keyword, required this.score});

  @override
  String toString() => '$keyword (${(score * 100).toStringAsFixed(1)}%)';
}

class _ScoredCandidate {
  final String text;
  final List<double> embedding;
  final double similarity;

  _ScoredCandidate({
    required this.text,
    required this.embedding,
    required this.similarity,
  });
}
