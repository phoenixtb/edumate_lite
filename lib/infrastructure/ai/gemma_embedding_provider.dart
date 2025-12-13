import 'package:embedding_gemma/embedding_gemma.dart';
import '../../domain/interfaces/embedding_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import 'gemma_session_manager.dart';

/// Gemma-based embedding provider using EmbeddingGemma-300M (2048 tokens)
/// Uses Google's RAG library via embedding_gemma package
/// Note: embedding_gemma internally uses LLM sessions, so must coordinate with inference
class GemmaEmbeddingProvider implements EmbeddingProvider {
  bool _isReady = false;
  EmbeddingGemma? _embeddingModel;

  static const _sessionUser = 'EmbeddingProvider';

  @override
  String get modelId => 'EmbeddingGemma-300M-2048';

  @override
  int get dimension => AppConstants.embeddingDimension;

  @override
  bool get isReady => _isReady;

  /// Expose embedding model for token counting in chunking strategy
  EmbeddingGemma get embeddingModel {
    if (_embeddingModel == null) {
      throw ModelException('Embedding model not initialized');
    }
    return _embeddingModel!;
  }

  @override
  Future<void> initialize() async {
    AppLogger.info('🚀 Initializing EmbeddingGemma provider (2048-token)...');

    try {
      // Check if active embedding model exists (flutter_gemma pattern)
      if (!await EmbeddingGemma.hasActiveModel()) {
        AppLogger.error('❌ No active embedding model found');
        throw ModelException(
          'No active embedding model. Use ModelDownloadService.loadEmbeddingModel() first.',
        );
      }

      AppLogger.info('✅ Active embedding model found, initializing...');

      // Get the active embedding model with GPU support if available
      try {
        _embeddingModel = await EmbeddingGemma.getActiveModel(
          backend: EmbeddingBackend.GPU,
        );

        _isReady = true;
        AppLogger.info('✅ Embedding model initialized with GPU backend');
      } catch (e) {
        AppLogger.warning(
          '⚠️  GPU initialization failed, falling back to CPU',
          e,
        );

        // Try CPU fallback
        try {
          _embeddingModel = await EmbeddingGemma.getActiveModel(
            backend: EmbeddingBackend.CPU,
          );

          _isReady = true;
          AppLogger.info('✅ Embedding model initialized with CPU backend');
        } catch (e2) {
          AppLogger.error('❌ CPU initialization also failed', e2);
          throw ModelException(
            'Failed to create embedding model instance. '
            'GPU Error: $e, CPU Error: $e2',
          );
        }
      }

      AppLogger.info(
        '✅ EmbeddingGemma ready (dimension: $dimension, max tokens: ${AppConstants.maxEmbeddingTokens})',
      );
    } catch (e, stackTrace) {
      _isReady = false;
      AppLogger.error(
        '❌ Embedding provider initialization failed',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    if (!_isReady || _embeddingModel == null) {
      AppLogger.error('❌ Embedding provider not initialized');
      throw ModelException('Embedding provider not initialized');
    }

    if (text.isEmpty) {
      AppLogger.warning('⚠️  Empty text provided to embed()');
      throw ModelException('Text cannot be empty');
    }

    // Acquire shared session lock - embedding uses same LLM session internally
    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 60),
    );

    if (!acquired) {
      throw ModelException(
        'AI is busy (${GemmaSessionManager.instance.currentUser}). Please wait.',
      );
    }

    try {
      AppLogger.debug(
        '📝 Generating document embedding (length: ${text.length})',
      );

      // Use embed() for material chunks (adds document prompt)
      final embedding = await _embeddingModel!.embed(text);

      AppLogger.debug('✅ Generated embedding (dim: ${embedding.length})');

      if (embedding.length != dimension) {
        AppLogger.warning(
          '⚠️  Unexpected embedding dimension: ${embedding.length}, expected: $dimension',
        );
      }

      return embedding;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Embedding generation failed', e, stackTrace);
      throw ModelException('Embedding generation failed: $e');
    } finally {
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  @override
  Future<List<double>> embedQuery(String query) async {
    if (!_isReady || _embeddingModel == null) {
      AppLogger.error('❌ Embedding provider not initialized');
      throw ModelException('Embedding provider not initialized');
    }

    if (query.isEmpty) {
      AppLogger.warning('⚠️  Empty query provided to embedQuery()');
      throw ModelException('Query cannot be empty');
    }

    // Acquire shared session lock - embedding uses same LLM session internally
    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 60),
    );

    if (!acquired) {
      throw ModelException(
        'AI is busy (${GemmaSessionManager.instance.currentUser}). Please wait.',
      );
    }

    try {
      AppLogger.debug(
        '🔍 Generating query embedding (length: ${query.length})',
      );

      // Use embedQuery() for RAG queries (adds task prompt)
      final embedding = await _embeddingModel!.embedQuery(query);

      AppLogger.debug('✅ Generated query embedding (dim: ${embedding.length})');

      if (embedding.length != dimension) {
        AppLogger.warning(
          '⚠️  Unexpected embedding dimension: ${embedding.length}, expected: $dimension',
        );
      }

      return embedding;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Query embedding generation failed', e, stackTrace);
      throw ModelException('Query embedding generation failed: $e');
    } finally {
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    AppLogger.info('📦 embedBatch called with ${texts.length} texts');

    if (!_isReady || _embeddingModel == null) {
      AppLogger.error('❌ Embedding provider not initialized');
      throw ModelException('Embedding provider not initialized');
    }

    if (texts.isEmpty) {
      AppLogger.warning('⚠️  Empty text list provided to embedBatch()');
      throw ModelException('Text list cannot be empty');
    }

    // Acquire shared session lock - embedding uses same LLM session internally
    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 300), // Longer timeout for batch
    );

    if (!acquired) {
      throw ModelException(
        'AI is busy (${GemmaSessionManager.instance.currentUser}). Please wait.',
      );
    }

    try {
      AppLogger.debug('🚀 Using native batch API for ${texts.length} texts');

      final embeddings = await _embeddingModel!.embedBatch(texts);

      AppLogger.info(
        '✅ Successfully generated ${embeddings.length} embeddings',
      );

      // Validate dimensions
      for (int i = 0; i < embeddings.length; i++) {
        if (embeddings[i].length != dimension) {
          AppLogger.warning(
            '⚠️  Embedding[$i] has unexpected dimension: ${embeddings[i].length}, expected: $dimension',
          );
        }
      }

      return embeddings;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ Batch embedding generation failed for ${texts.length} texts',
        e,
        stackTrace,
      );
      throw ModelException('Batch embedding generation failed: $e');
    } finally {
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  @override
  Future<void> dispose() async {
    // Release any held lock
    if (GemmaSessionManager.instance.currentUser == _sessionUser) {
      GemmaSessionManager.instance.release(_sessionUser);
    }
    _isReady = false;
    if (_embeddingModel != null) {
      _embeddingModel!.dispose();
      _embeddingModel = null;
    }
    AppLogger.info('✅ Embedding provider disposed');
  }
}
