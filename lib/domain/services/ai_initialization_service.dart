import 'package:dartz/dartz.dart';
import '../interfaces/embedding_provider.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import 'inference_router.dart';

/// Service to initialize AI providers after models are loaded
class AiInitializationService {
  final EmbeddingProvider embeddingProvider;
  final InferenceRouter inferenceRouter;

  AiInitializationService({
    required this.embeddingProvider,
    required this.inferenceRouter,
  });

  /// Initialize both AI providers
  Future<Either<Failure, Unit>> initializeProviders() async {
    try {
      // Initialize embedding provider
      await embeddingProvider.initialize();
      AppLogger.info('✅ Embedding provider initialized');

      // Initialize inference router (loads appropriate model based on preference)
      await inferenceRouter.initialize();
      AppLogger.info('✅ Inference router initialized');

      return const Right(unit);
    } catch (e) {
      return Left(ModelFailure('Failed to initialize AI providers: $e'));
    }
  }

  /// Check if providers are ready
  bool get areProvidersReady => embeddingProvider.isReady;
}

