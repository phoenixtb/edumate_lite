import 'package:dartz/dartz.dart';
import '../interfaces/embedding_provider.dart';
import '../interfaces/vector_store.dart';
import '../interfaces/inference_provider.dart';
import '../entities/message.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/token_estimator.dart';
import '../../core/prompts/prompt_templates.dart';

/// RAG (Retrieval-Augmented Generation) Engine
/// Orchestrates retrieval and generation for Q&A
class RagEngine {
  final EmbeddingProvider embeddingProvider;
  final VectorStore vectorStore;
  final InferenceProvider inferenceProvider;

  /// Configuration
  final int retrievalTopK;
  final double similarityThreshold;
  final int maxContextTokens;

  RagEngine({
    required this.embeddingProvider,
    required this.vectorStore,
    required this.inferenceProvider,
    this.retrievalTopK = AppConstants.retrievalTopK,
    this.similarityThreshold = AppConstants.similarityThreshold,
    this.maxContextTokens = AppConstants.maxContextTokens,
  });

  /// Answer a question using RAG
  ///
  /// Returns Either Failure or Stream RagResponse
  Future<Either<Failure, Stream<RagResponse>>> answer(
    String query, {
    List<int>? materialIds,
    List<Message>? conversationHistory,
  }) async {
    try {
      // Validate inputs
      if (query.trim().isEmpty) {
        return Left(ProcessingFailure('Query cannot be empty'));
      }

      if (!embeddingProvider.isReady) {
        return Left(ModelFailure('Embedding provider not ready'));
      }

      if (!inferenceProvider.isReady) {
        return Left(ModelFailure('Inference provider not ready'));
      }

      // Generate query embedding (optimized for retrieval)
      final queryEmbedding = await embeddingProvider.embedQuery(query);

      // CRITICAL: Wait for embedding's internal LLM session to fully close
      // embedding_gemma creates native sessions that persist after the call returns
      // Qualcomm devices (Snapdragon) require longer cleanup time than MediaTek
      await Future.delayed(const Duration(milliseconds: 500));

      // Retrieve more chunks than needed, then rerank
      final candidateChunks = await vectorStore.search(
        queryEmbedding,
        topK: retrievalTopK * 2, // Fetch 2x for reranking
        threshold: similarityThreshold,
        materialIds: materialIds,
      );

      // Handle no relevant context
      if (candidateChunks.isEmpty) {
        return Right(_noContextFoundStream(query));
      }

      // Rerank chunks based on query term relevance
      final retrievedChunks = _rerankChunks(candidateChunks, query, retrievalTopK);

      // Build context from retrieved chunks
      final context = _buildContext(retrievedChunks);

      // Calculate confidence score (average of chunk scores)
      final confidenceScore = retrievedChunks.isEmpty
          ? 0.0
          : retrievedChunks.map((c) => c.score).reduce((a, b) => a + b) /
              retrievedChunks.length;

      // Generate response stream
      final responseStream = _generateResponseStream(
        query: query,
        context: context,
        conversationHistory: conversationHistory,
        retrievedChunks: retrievedChunks,
        confidenceScore: confidenceScore,
      );

      return Right(responseStream);
    } catch (e) {
      return Left(ProcessingFailure('RAG pipeline failed: $e'));
    }
  }

  /// Generate a quiz from materials
  Future<Either<Failure, Stream<RagResponse>>> generateQuiz(
    List<int> materialIds, {
    int questionCount = 5,
    String? topic,
    String? difficulty,
  }) async {
    try {
      if (materialIds.isEmpty) {
        return Left(ProcessingFailure('No materials specified'));
      }

      if (!inferenceProvider.isReady) {
        return Left(ModelFailure('Inference provider not ready'));
      }

      // Retrieve sample chunks from materials
      final allChunks = <ScoredChunk>[];
      for (final materialId in materialIds) {
        final chunks = await vectorStore.getByMaterial(materialId);
        // Add with default score for quiz generation
        allChunks.addAll(chunks.map((c) => ScoredChunk(chunk: c, score: 1.0)));
      }

      if (allChunks.isEmpty) {
        return Left(ProcessingFailure('No content found in materials'));
      }

      // Build context from chunks
      final context = _buildContext(allChunks.take(10).toList());

      // Use Quiz prompt template
      final quizTemplate = PromptFactory.get(PromptType.quiz);
      final formattedContext = quizTemplate.formatContext(context);
      final quizPrompt = quizTemplate.buildPrompt({
        'questionCount': questionCount,
        'topic': topic,
        'difficulty': difficulty ?? 'medium',
      });

      final responseStream = inferenceProvider.generate(
        systemPrompt: quizTemplate.systemPrompt,
        context: formattedContext,
        query: quizPrompt,
      );

      return Right(_wrapInRagResponse(responseStream, allChunks.take(10).toList()));
    } catch (e) {
      return Left(ProcessingFailure('Quiz generation failed: $e'));
    }
  }

  /// Rerank chunks based on query term overlap
  /// Combines embedding similarity with lexical relevance
  List<ScoredChunk> _rerankChunks(
    List<ScoredChunk> candidates,
    String query,
    int topK,
  ) {
    // Extract query terms (lowercase, remove common words)
    final queryTerms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .where((t) => !_stopWords.contains(t))
        .toSet();

    if (queryTerms.isEmpty) {
      // Fallback to original order if no meaningful terms
      return candidates.take(topK).toList();
    }

    // Score each chunk based on term overlap + embedding score
    final reranked = candidates.map((sc) {
      final contentLower = sc.chunk.content.toLowerCase();
      
      // Count matching terms
      int termMatches = 0;
      for (final term in queryTerms) {
        if (contentLower.contains(term)) {
          termMatches++;
        }
      }
      
      // Combined score: 70% embedding, 30% term relevance
      final termScore = queryTerms.isEmpty ? 0.0 : termMatches / queryTerms.length;
      final combinedScore = (sc.score * 0.7) + (termScore * 0.3);
      
      return ScoredChunk(chunk: sc.chunk, score: combinedScore);
    }).toList();

    // Sort by combined score descending
    reranked.sort((a, b) => b.score.compareTo(a.score));

    return reranked.take(topK).toList();
  }

  // Common stop words to ignore in reranking
  static const _stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
    'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by',
    'from', 'as', 'into', 'through', 'during', 'before', 'after', 'above',
    'below', 'between', 'under', 'again', 'further', 'then', 'once',
    'what', 'which', 'who', 'whom', 'this', 'that', 'these', 'those',
    'am', 'and', 'but', 'if', 'or', 'because', 'until',
    'while', 'about', 'against', 'how', 'why', 'when', 'where', 'please',
    'explain', 'tell', 'me', 'you', 'briefly', 'describe',
  };

  /// Build context string from retrieved chunks
  String _buildContext(List<ScoredChunk> chunks) {
    final buffer = StringBuffer();
    var currentTokens = 0;

    for (final scoredChunk in chunks) {
      final chunk = scoredChunk.chunk;
      final chunkTokens = TokenEstimator.estimate(chunk.content);

      // Stop if adding this chunk would exceed limit
      if (currentTokens + chunkTokens > maxContextTokens) {
        break;
      }

      // Add chunk with metadata
      buffer.writeln('[Source: ${chunk.chunkType}]');
      if (chunk.pageNumber != null) {
        buffer.writeln('[Page: ${chunk.pageNumber}]');
      }
      buffer.writeln(chunk.content);
      buffer.writeln();

      currentTokens += chunkTokens;
    }

    return buffer.toString();
  }

  /// Generate response stream with RAG metadata
  Stream<RagResponse> _generateResponseStream({
    required String query,
    required String context,
    List<Message>? conversationHistory,
    required List<ScoredChunk> retrievedChunks,
    required double confidenceScore,
  }) async* {
    // Add confidence warning if low
    if (confidenceScore < 0.7) {
      yield RagResponse(
        content: '⚠️ Low confidence - the answer may not be fully accurate.\n\n',
        isComplete: false,
        retrievedChunks: retrievedChunks,
        confidenceScore: confidenceScore,
      );
    }

    // Use QA prompt template for better quality responses
    final qaTemplate = PromptFactory.get(PromptType.qa);
    final formattedContext = qaTemplate.formatContext(context);
    final userPrompt = qaTemplate.buildPrompt({'query': query});

    // Stream the actual response
    final responseStream = inferenceProvider.generate(
      systemPrompt: qaTemplate.systemPrompt,
      context: formattedContext,
      query: userPrompt,
      conversationHistory: conversationHistory,
    );

    await for (final chunk in responseStream) {
      yield RagResponse(
        content: chunk,
        isComplete: false,
        retrievedChunks: retrievedChunks,
        confidenceScore: confidenceScore,
      );
    }

    // Final marker
    yield RagResponse(
      content: '',
      isComplete: true,
      retrievedChunks: retrievedChunks,
      confidenceScore: confidenceScore,
    );
  }

  /// Handle no context found scenario
  Stream<RagResponse> _noContextFoundStream(String query) async* {
    const message = '''I don't have enough information in your study materials to answer this question accurately.

Possible reasons:
• This topic hasn't been uploaded yet
• Try rephrasing your question
• Upload relevant materials for this topic

Would you like to:
1. Upload materials about this topic
2. Try a different question
3. Browse your existing materials''';

    yield RagResponse(
      content: message,
      isComplete: true,
      retrievedChunks: [],
      confidenceScore: 0.0,
    );
  }

  /// Wrap inference stream in RagResponse
  Stream<RagResponse> _wrapInRagResponse(
    Stream<String> stream,
    List<ScoredChunk> chunks,
  ) async* {
    await for (final chunk in stream) {
      yield RagResponse(
        content: chunk,
        isComplete: false,
        retrievedChunks: chunks,
        confidenceScore: 1.0,
      );
    }

    yield RagResponse(
      content: '',
      isComplete: true,
      retrievedChunks: chunks,
      confidenceScore: 1.0,
    );
  }

  /// Summarize content from materials
  Future<Either<Failure, Stream<RagResponse>>> summarize(
    List<int> materialIds, {
    String style = 'bullet',
    int maxPoints = 5,
  }) async {
    try {
      if (materialIds.isEmpty) {
        return Left(ProcessingFailure('No materials specified'));
      }

      if (!inferenceProvider.isReady) {
        return Left(ModelFailure('Inference provider not ready'));
      }

      // Retrieve chunks from materials
      final allChunks = <ScoredChunk>[];
      for (final materialId in materialIds) {
        final chunks = await vectorStore.getByMaterial(materialId);
        allChunks.addAll(chunks.map((c) => ScoredChunk(chunk: c, score: 1.0)));
      }

      if (allChunks.isEmpty) {
        return Left(ProcessingFailure('No content found in materials'));
      }

      final context = _buildContext(allChunks.take(10).toList());

      // Use Summary prompt template
      final summaryTemplate = PromptFactory.get(PromptType.summary);
      final formattedContext = summaryTemplate.formatContext(context);
      final summaryPrompt = summaryTemplate.buildPrompt({
        'style': style,
        'maxPoints': maxPoints,
      });

      final responseStream = inferenceProvider.generate(
        systemPrompt: summaryTemplate.systemPrompt,
        context: formattedContext,
        query: summaryPrompt,
      );

      return Right(_wrapInRagResponse(responseStream, allChunks.take(10).toList()));
    } catch (e) {
      return Left(ProcessingFailure('Summarization failed: $e'));
    }
  }

  /// Explain a concept using materials
  Future<Either<Failure, Stream<RagResponse>>> explain(
    String concept, {
    List<int>? materialIds,
  }) async {
    try {
      if (!embeddingProvider.isReady) {
        return Left(ModelFailure('Embedding provider not ready'));
      }

      if (!inferenceProvider.isReady) {
        return Left(ModelFailure('Inference provider not ready'));
      }

      // Generate embedding for the concept
      final queryEmbedding = await embeddingProvider.embedQuery(concept);

      // Retrieve relevant chunks
      final retrievedChunks = await vectorStore.search(
        queryEmbedding,
        topK: retrievalTopK,
        threshold: similarityThreshold,
        materialIds: materialIds,
      );

      if (retrievedChunks.isEmpty) {
        return Right(_noContextFoundStream(concept));
      }

      final context = _buildContext(retrievedChunks);

      // Use Explain prompt template
      final explainTemplate = PromptFactory.get(PromptType.explain);
      final formattedContext = explainTemplate.formatContext(context);
      final explainPrompt = explainTemplate.buildPrompt({'concept': concept});

      final responseStream = inferenceProvider.generate(
        systemPrompt: explainTemplate.systemPrompt,
        context: formattedContext,
        query: explainPrompt,
      );

      return Right(_wrapInRagResponse(responseStream, retrievedChunks));
    } catch (e) {
      return Left(ProcessingFailure('Explanation failed: $e'));
    }
  }
}

/// Response from RAG engine
class RagResponse {
  final String content;
  final bool isComplete;
  final List<ScoredChunk>? retrievedChunks;
  final double? confidenceScore;

  RagResponse({
    required this.content,
    this.isComplete = false,
    this.retrievedChunks,
    this.confidenceScore,
  });
}

