import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:embedding_gemma/embedding_gemma.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';
import '../../stores/model_download_store.dart';

/// Service to load AI models from bundled assets
/// Models are pre-downloaded and packaged with the app
class ModelDownloadService {
  final ModelDownloadStore downloadStore;

  ModelDownloadService(this.downloadStore);

  /// Load embedding model from bundled assets (flutter_gemma pattern)
  Future<Either<Failure, Unit>> loadEmbeddingModel() async {
    try {
      downloadStore.setEmbeddingStatus(ModelDownloadStatus.downloading);
      downloadStore.setEmbeddingProgress(0.0);

      // Install embedding model using builder pattern (same as flutter_gemma)
      await EmbeddingGemma.installModel()
          .modelFromAsset(AppConstants.embeddingModelAsset)
          .tokenizerFromAsset(AppConstants.embeddingTokenizerAsset)
          .withProgress((progress) {
            Future.microtask(() {
              downloadStore.setEmbeddingProgress(progress);
            });
          })
          .install();

      downloadStore.setEmbeddingStatus(ModelDownloadStatus.completed);
      return const Right(unit);
    } catch (e) {
      downloadStore.setEmbeddingStatus(ModelDownloadStatus.failed);
      downloadStore.setEmbeddingError(e.toString());
      return Left(StorageFailure('Failed to load embedding model: $e'));
    }
  }

  /// Load inference model from bundled assets (async - non-blocking)
  Future<Either<Failure, Unit>> loadInferenceModel() async {
    try {
      downloadStore.setInferenceStatus(ModelDownloadStatus.downloading);
      downloadStore.setInferenceProgress(0.0);

      // Install inference model from bundled assets
      // This runs asynchronously and won't block UI
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      )
          .fromAsset(AppConstants.inferenceModelAsset)
          .withProgress((progress) {
            // Update progress - this callback runs on different thread
            Future.microtask(() {
              downloadStore.setInferenceProgress(progress / 100);
            });
          })
          .install();

      downloadStore.setInferenceStatus(ModelDownloadStatus.completed);
      return const Right(unit);
    } catch (e) {
      downloadStore.setInferenceStatus(ModelDownloadStatus.failed);
      downloadStore.setInferenceError(e.toString());
      return Left(StorageFailure('Failed to load inference model: $e'));
    }
  }

  /// Check if models are already downloaded
  Future<bool> checkModelsDownloaded() async {
    try {
      debugPrint('🔷 [ModelDownload] checkModelsDownloaded started');
      
      // Check if embedding model is installed (same pattern as flutter_gemma)
      debugPrint('🔷 [ModelDownload] Checking embedding model...');
      final hasEmbedding = await EmbeddingGemma.hasActiveModel();
      debugPrint('🔷 [ModelDownload] hasEmbedding = $hasEmbedding');
      
      // Check if inference model exists in flutter_gemma registry
      debugPrint('🔷 [ModelDownload] Checking inference model...');
      final hasInference = FlutterGemma.hasActiveModel();
      debugPrint('🔷 [ModelDownload] hasInference = $hasInference');

      if (hasEmbedding) {
        downloadStore.setEmbeddingStatus(ModelDownloadStatus.completed);
      }

      if (hasInference) {
        downloadStore.setInferenceStatus(ModelDownloadStatus.completed);
      }

      debugPrint('🔷 [ModelDownload] checkModelsDownloaded done: ${hasEmbedding && hasInference}');
      return hasEmbedding && hasInference;
    } catch (e) {
      debugPrint('❌ [ModelDownload] checkModelsDownloaded error: $e');
      return false;
    }
  }

  /// Get list of all installed models
  Future<List<String>> getInstalledModels() async {
    try {
      return await FlutterGemma.listInstalledModels();
    } catch (e) {
      return [];
    }
  }

  /// Delete a model
  Future<Either<Failure, Unit>> deleteModel(String modelName) async {
    try {
      await FlutterGemma.uninstallModel(modelName);
      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure('Failed to delete model: $e'));
    }
  }

  /// Download Qwen 2.5 from HuggingFace (for better text with function calling)
  /// Note: This reuses the Phi-4 UI state for backwards compatibility
  Future<Either<Failure, Unit>> downloadPhi4Model() async {
    try {
      downloadStore.setPhi4Status(ModelDownloadStatus.downloading);
      downloadStore.setPhi4Progress(0.0);

      await FlutterGemma.installModel(
        modelType: ModelType.qwen,
      )
          .fromNetwork(AppConstants.qwenModelUrl)
          .withProgress((progress) {
            Future.microtask(() {
              downloadStore.setPhi4Progress(progress / 100);
            });
          })
          .install();

      downloadStore.setPhi4Status(ModelDownloadStatus.completed);
      return const Right(unit);
    } catch (e) {
      downloadStore.setPhi4Status(ModelDownloadStatus.failed);
      downloadStore.setPhi4Error(e.toString());
      return Left(NetworkFailure('Failed to download Qwen: $e'));
    }
  }

  /// Check if Qwen is available (reuses method name for backwards compat)
  Future<bool> hasPhi4Model() async {
    try {
      final models = await getInstalledModels();
      return models.any((m) => m.toLowerCase().contains('qwen'));
    } catch (e) {
      return false;
    }
  }

  /// Delete Qwen model to free storage
  Future<Either<Failure, Unit>> deletePhi4Model() async {
    try {
      final models = await getInstalledModels();
      final qwenModel = models.firstWhere(
        (m) => m.toLowerCase().contains('qwen'),
        orElse: () => '',
      );
      if (qwenModel.isNotEmpty) {
        await FlutterGemma.uninstallModel(qwenModel);
      }
      downloadStore.setPhi4Status(ModelDownloadStatus.notStarted);
      downloadStore.setPhi4Progress(0.0);
      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure('Failed to delete Qwen: $e'));
    }
  }
}



