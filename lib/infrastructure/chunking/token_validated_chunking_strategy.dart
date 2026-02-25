import '../../domain/interfaces/chunking_strategy.dart';
import '../../core/constants/app_constants.dart';
import '../../infrastructure/ai/gemma_embedding_provider.dart';
import '../../core/utils/logger.dart';

/// Token-validated chunking using recursive binary splitting.
///
/// Algorithm:
/// 1. Accumulate paragraphs by char estimate (fast)
/// 2. Validate with actual token count
/// 3. If over limit → recursive binary split by chars (respecting boundaries)
/// 4. Words are atomic - single word over limit = reader problem
///
/// No data loss, no word slicing.
class TokenValidatedChunkingStrategy implements ChunkingStrategy {
  final GemmaEmbeddingProvider embeddingProvider;

  // Token limit (EmbeddingGemma-300M max: 2048)
  // Using 1600 with clean text (garbled Unicode was causing discrepancy)
  static const int _maxTokens = 1600;

  // Char target for paragraph accumulation (~2.5 chars/token)
  static const int _targetChars = 4000;
  static const int _overlapChars = 200;

  TokenValidatedChunkingStrategy({required this.embeddingProvider});

  /// Count tokens using embedding model's tokenizer
  Future<int> _countTokens(String text) async {
    if (text.isEmpty) return 0;
    if (!embeddingProvider.isReady) {
      throw StateError('Embedding provider must be initialized');
    }
    return await embeddingProvider.embeddingModel.countTokens(
      text,
      withPrompt: true,
    );
  }

  @override
  String get strategyId => 'token_validated_v5';

  @override
  int get targetChunkSize => AppConstants.targetChunkSizeTokens;

  @override
  int get chunkOverlap => AppConstants.chunkOverlapTokens;

  @override
  Future<List<ChunkResult>> chunk(
    String text,
    Map<String, dynamic> metadata,
  ) async {
    if (text.isEmpty) return [];

    final pageNumber = metadata['pageNumber'] as int?;
    final sourceTitle = metadata['title'] as String?;

    final paragraphs = _splitIntoParagraphs(text);
    AppLogger.debug(
      '[Chunking] Processing ${paragraphs.length} paragraphs, ${text.length} chars',
    );

    final results = <ChunkResult>[];
    var currentParagraphs = <String>[];
    var currentChars = 0;
    var sequenceIndex = 0;

    for (final paragraph in paragraphs) {
      final newChars = currentChars + paragraph.length + 2;

      // Accumulate until we hit target
      if (newChars > _targetChars && currentParagraphs.isNotEmpty) {
        // Validate and potentially split this batch
        final chunks = await _processText(
          currentParagraphs.join('\n\n'),
          pageNumber,
          sequenceIndex,
          sourceTitle,
        );
        results.addAll(chunks);
        sequenceIndex += chunks.length;

        // Start new with overlap
        final overlap = _getOverlapText(currentParagraphs);
        currentParagraphs = overlap.isNotEmpty
            ? [overlap, paragraph]
            : [paragraph];
        currentChars = currentParagraphs.join('\n\n').length;
      } else {
        currentParagraphs.add(paragraph);
        currentChars = newChars;
      }
    }

    // Process remaining
    if (currentParagraphs.isNotEmpty) {
      final chunks = await _processText(
        currentParagraphs.join('\n\n'),
        pageNumber,
        sequenceIndex,
        sourceTitle,
      );
      results.addAll(chunks);
    }

    AppLogger.info(
      '[Chunking] Created ${results.length} chunks from ${paragraphs.length} paragraphs',
    );
    return results;
  }

  /// Core recursive function: validate text, binary split if over limit
  Future<List<ChunkResult>> _processText(
    String text,
    int? pageNumber,
    int startSequence,
    String? sourceTitle,
  ) async {
    final tokens = await _countTokens(text);

    // Base case: under limit - valid chunk
    if (tokens <= _maxTokens) {
      return [
        _createChunk(text, tokens, pageNumber, startSequence, sourceTitle),
      ];
    }

    // Over limit - binary split
    return await _binarySplit(text, pageNumber, startSequence, sourceTitle);
  }

  /// Binary split text by chars, respecting sentence > word boundaries
  Future<List<ChunkResult>> _binarySplit(
    String text,
    int? pageNumber,
    int startSequence,
    String? sourceTitle,
  ) async {
    final tokens = await _countTokens(text);

    // Base case: under limit
    if (tokens <= _maxTokens) {
      return [
        _createChunk(text, tokens, pageNumber, startSequence, sourceTitle),
      ];
    }

    // Find split point near middle, respecting boundaries
    final (left, right) = _splitAtBoundary(text);

    // Can't split further (single word/token)
    if (left.isEmpty || right.isEmpty) {
      AppLogger.warning(
        '[Chunking] Cannot split further: ${text.length} chars, $tokens tokens',
      );
      // Return as-is - this is a reader problem, not chunker's
      return [
        _createChunk(text, tokens, pageNumber, startSequence, sourceTitle),
      ];
    }

    // Recursively process both halves
    final leftChunks = await _binarySplit(
      left,
      pageNumber,
      startSequence,
      sourceTitle,
    );

    final rightChunks = await _binarySplit(
      right,
      pageNumber,
      startSequence + leftChunks.length,
      sourceTitle,
    );

    return [...leftChunks, ...rightChunks];
  }

  /// Split text at middle, respecting sentence > word boundaries
  /// Returns (left, right) tuple
  (String, String) _splitAtBoundary(String text) {
    final mid = text.length ~/ 2;

    // Try to find sentence boundary near middle
    final sentenceSplit = _findSentenceBoundary(text, mid);
    if (sentenceSplit != null) {
      return (
        text.substring(0, sentenceSplit).trim(),
        text.substring(sentenceSplit).trim(),
      );
    }

    // Fallback: find word boundary near middle
    final wordSplit = _findWordBoundary(text, mid);
    if (wordSplit != null) {
      return (
        text.substring(0, wordSplit).trim(),
        text.substring(wordSplit).trim(),
      );
    }

    // Last resort: split at exact middle (should not happen with normal text)
    return (text.substring(0, mid).trim(), text.substring(mid).trim());
  }

  /// Find sentence boundary nearest to position
  int? _findSentenceBoundary(String text, int position) {
    // Search window: 40% of text length on each side
    final searchRange = (text.length * 0.4).toInt();
    final start = (position - searchRange).clamp(0, text.length);
    final end = (position + searchRange).clamp(0, text.length);

    // Find all sentence endings in range
    final sentenceEnders = RegExp(r'[.!?]\s+');
    int? bestSplit;
    int bestDistance = searchRange + 1;

    for (final match in sentenceEnders.allMatches(text, start)) {
      if (match.end > end) break;

      final splitPoint = match.end;
      final distance = (splitPoint - position).abs();

      if (distance < bestDistance) {
        bestDistance = distance;
        bestSplit = splitPoint;
      }
    }

    return bestSplit;
  }

  /// Find word boundary nearest to position
  int? _findWordBoundary(String text, int position) {
    // Search for space/newline nearest to position
    final searchRange = (text.length * 0.3).toInt();

    // Search forward
    for (
      var i = position;
      i < (position + searchRange).clamp(0, text.length);
      i++
    ) {
      if (text[i] == ' ' || text[i] == '\n') {
        return i + 1;
      }
    }

    // Search backward
    for (
      var i = position;
      i > (position - searchRange).clamp(0, text.length);
      i--
    ) {
      if (text[i] == ' ' || text[i] == '\n') {
        return i + 1;
      }
    }

    return null;
  }

  String _getOverlapText(List<String> paragraphs) {
    if (paragraphs.isEmpty) return '';

    final lastPara = paragraphs.last;
    if (lastPara.length <= _overlapChars) {
      return lastPara;
    }

    // Get last sentence if fits
    final sentences = _splitIntoSentences(lastPara);
    if (sentences.isNotEmpty && sentences.last.length <= _overlapChars) {
      return sentences.last;
    }

    return '';
  }

  ChunkResult _createChunk(
    String content,
    int tokens,
    int? pageNumber,
    int sequenceIndex,
    String? sourceTitle,
  ) {
    final trimmed = content.trim();
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final preview = trimmed.length > 100
        ? '${trimmed.substring(0, 100)}...'
        : trimmed;

    return ChunkResult(
      content: trimmed,
      chunkType: 'paragraph',
      pageNumber: pageNumber,
      sectionIndex: sequenceIndex,
      metadata: {
        'words': words,
        'chars': trimmed.length,
        'tokens': tokens,
        'preview': preview.replaceAll('\n', ' '),
        if (sourceTitle != null) 'source_title': sourceTitle,
      },
    );
  }

  List<String> _splitIntoParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  List<String> _splitIntoSentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
