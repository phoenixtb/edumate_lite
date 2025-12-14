import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../config/service_locator.dart';
import '../../stores/app_store.dart';

// #region agent log
void _debugLogMM(String hypId, String msg, Map<String, dynamic> data) {
  AppLogger.debug('🔬 [DEBUG:$hypId] $msg: ${jsonEncode(data)}');
}
// #endregion

/// Tracks which inference model is currently loaded
enum ActiveModelType {
  none,
  gemma,
  phi4, // Deprecated - has MediaPipe template issues
  deepseek,
}

/// Manages model loading/unloading for inference
/// 
/// flutter_gemma only supports ONE active model at a time.
/// This manager handles switching between Gemma and DeepSeek.
class ModelManager {
  ModelManager._();
  static final ModelManager instance = ModelManager._();

  ActiveModelType _activeModel = ActiveModelType.none;
  InferenceModel? _currentModel;
  bool _isLoading = false;
  bool _returnToDeepseekAfterVision = false;

  ActiveModelType get activeModel => _activeModel;
  InferenceModel? get currentModel => _currentModel;
  bool get isLoading => _isLoading;
  bool get shouldReturnToPhi4 => _returnToDeepseekAfterVision; // Backwards compat

  /// Check if DeepSeek is installed
  Future<bool> isDeepseekInstalled() async {
    try {
      final models = await FlutterGemma.listInstalledModels();
      return models.any((m) => m.toLowerCase().contains('deepseek'));
    } catch (e) {
      return false;
    }
  }

  /// Check if Phi-4 is installed (deprecated - kept for backwards compat)
  Future<bool> isPhi4Installed() async {
    try {
      final models = await FlutterGemma.listInstalledModels();
      return models.any((m) => m.toLowerCase().contains('phi'));
    } catch (e) {
      return false;
    }
  }

  /// Load initial model based on user preference
  Future<void> loadInitialModel() async {
    final appStore = getIt<AppStore>();
    final deepseekAvailable = await isDeepseekInstalled();
    
    if (deepseekAvailable) {
      appStore.setPhi4ModelReady(true); // Reuse the flag for DeepSeek
    }

    if (deepseekAvailable && appStore.preferPhi4ForText) {
      AppLogger.info('🚀 [ModelManager] Loading DeepSeek (user preference)');
      await _loadDeepseek();
    } else {
      AppLogger.info('🚀 [ModelManager] Loading Gemma 3n (default)');
      await _loadGemma();
    }
  }

  /// Switch to Gemma (for vision tasks)
  Future<bool> switchToGemma({bool markReturnToDeepseek = false}) async {
    if (_activeModel == ActiveModelType.gemma) {
      AppLogger.debug('✅ [ModelManager] Gemma already active');
      return true;
    }

    if (_isLoading) {
      AppLogger.warning('⚠️ [ModelManager] Model loading in progress');
      return false;
    }

    AppLogger.info('🔄 [ModelManager] Switching to Gemma...');
    
    // Remember to return to DeepSeek later
    if (markReturnToDeepseek && _activeModel == ActiveModelType.deepseek) {
      _returnToDeepseekAfterVision = true;
      AppLogger.debug('📌 [ModelManager] Will return to DeepSeek after vision task');
    }

    await _unloadCurrentModel();
    return await _loadGemma();
  }

  /// Switch to DeepSeek (for better text reasoning)
  Future<bool> switchToDeepseek() async {
    if (_activeModel == ActiveModelType.deepseek) {
      AppLogger.debug('✅ [ModelManager] DeepSeek already active');
      return true;
    }

    if (_isLoading) {
      AppLogger.warning('⚠️ [ModelManager] Model loading in progress');
      return false;
    }

    final deepseekAvailable = await isDeepseekInstalled();
    if (!deepseekAvailable) {
      AppLogger.warning('⚠️ [ModelManager] DeepSeek not installed');
      return false;
    }

    AppLogger.info('🔄 [ModelManager] Switching to DeepSeek...');
    await _unloadCurrentModel();
    return await _loadDeepseek();
  }

  /// Backwards compat - switch to Phi-4 (actually loads DeepSeek)
  Future<bool> switchToPhi4() async {
    return await switchToDeepseek();
  }

  /// Return to DeepSeek if flagged (after vision task)
  Future<void> returnToPhi4IfNeeded() async {
    if (!_returnToDeepseekAfterVision) return;
    
    final appStore = getIt<AppStore>();
    if (!appStore.preferPhi4ForText) {
      _returnToDeepseekAfterVision = false;
      return;
    }

    AppLogger.info('🔄 [ModelManager] Returning to DeepSeek (after vision)');
    _returnToDeepseekAfterVision = false;
    await switchToDeepseek();
  }

  /// Ensure correct model is loaded for text query
  Future<bool> ensureModelForText() async {
    final appStore = getIt<AppStore>();
    
    // Check if we need to return to DeepSeek
    if (_returnToDeepseekAfterVision && appStore.preferPhi4ForText) {
      AppLogger.info('🔄 [ModelManager] Switching back to DeepSeek for text');
      _returnToDeepseekAfterVision = false;
      return await switchToDeepseek();
    }
    
    // Check if preference matches active model
    if (appStore.preferPhi4ForText && appStore.isPhi4ModelReady) {
      if (_activeModel != ActiveModelType.deepseek) {
        return await switchToDeepseek();
      }
    } else {
      if (_activeModel != ActiveModelType.gemma) {
        return await switchToGemma();
      }
    }
    
    return true;
  }

  /// Clear return flag (user manually switched preference)
  void clearReturnFlag() {
    _returnToDeepseekAfterVision = false;
  }

  Future<bool> _loadGemma() async {
    _isLoading = true;
    try {
      // Always reinstall Gemma when loading it (to switch from DeepSeek)
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      )
          .fromAsset(AppConstants.inferenceModelAsset)
          .install();

      _currentModel = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        supportImage: true,
        preferredBackend: PreferredBackend.gpu,
      );

      _activeModel = ActiveModelType.gemma;
      AppLogger.info('✅ [ModelManager] Gemma 3n loaded successfully');
      
      final appStore = getIt<AppStore>();
      appStore.setInferenceModelReady(true);
      
      return true;
    } catch (e) {
      AppLogger.error('❌ [ModelManager] Failed to load Gemma: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  Future<bool> _loadDeepseek() async {
    _isLoading = true;
    final startTime = DateTime.now();
    // #region agent log
    _debugLogMM('H', 'loadDeepseek_start', {'time': startTime.toIso8601String(), 'prevActiveModel': _activeModel.toString()});
    // #endregion
    try {
      // Check if DeepSeek is already installed (on disk)
      final models = await FlutterGemma.listInstalledModels();
      final deepseekName = models.firstWhere(
        (m) => m.toLowerCase().contains('deepseek'),
        orElse: () => '',
      );
      
      // #region agent log
      _debugLogMM('H', 'installedModels', {'models': models, 'deepseekName': deepseekName, 'elapsedMs': DateTime.now().difference(startTime).inMilliseconds});
      // #endregion

      if (deepseekName.isEmpty) {
        AppLogger.warning('⚠️ [ModelManager] DeepSeek not found in installed models');
        return await _loadGemma();
      }

      // CRITICAL: installModel() must be called to load model INTO MEMORY
      // listInstalledModels() only shows what's on disk, not what's loaded!
      // This is why Gemma takes time (loading into memory) but DeepSeek was instant (not loading)
      AppLogger.info('🔄 [ModelManager] Loading DeepSeek into memory (this may take time)...');
      
      // #region agent log
      _debugLogMM('H', 'before_installModel', {'deepseekName': deepseekName, 'elapsedMs': DateTime.now().difference(startTime).inMilliseconds});
      // #endregion
      
      // Use fromBundled() to load from internal storage where the download was saved
      // This is similar to how Gemma uses fromAsset() but for downloaded models
      await FlutterGemma.installModel(
        modelType: ModelType.deepSeek,
      )
          .fromBundled(deepseekName) // Use the installed model name from listInstalledModels()
          .withProgress((progress) {
            // Log progress
            if (progress.toInt() % 10 == 0) {
              AppLogger.debug('📦 [ModelManager] DeepSeek loading: ${progress.toInt()}%');
            }
          })
          .install();
      
      final installTime = DateTime.now().difference(startTime).inMilliseconds;
      // #region agent log
      _debugLogMM('H', 'after_installModel', {'installTimeMs': installTime});
      // #endregion
      AppLogger.info('📦 [ModelManager] DeepSeek install completed (${installTime}ms)');

      // #region agent log
      _debugLogMM('H', 'before_getActiveModel', {'tryingBackend': 'gpu', 'maxTokens': 1024, 'elapsedMs': DateTime.now().difference(startTime).inMilliseconds});
      // #endregion
      
      // Use GPU backend with max tokens at GPU cache limit
      _currentModel = await FlutterGemma.getActiveModel(
        maxTokens: 1280, // GPU cache limit - prompts must stay under this
        supportImage: false,
        preferredBackend: PreferredBackend.gpu,
      );
      
      final getActiveTime = DateTime.now().difference(startTime).inMilliseconds;
      // #region agent log
      _debugLogMM('H', 'after_getActiveModel', {'modelNull': _currentModel == null, 'modelHashCode': _currentModel?.hashCode, 'getActiveTimeMs': getActiveTime});
      // #endregion

      // Wait for model to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_currentModel == null) {
        AppLogger.warning('⚠️ [ModelManager] DeepSeek model is null after load');
        return await _loadGemma();
      }

      _activeModel = ActiveModelType.deepseek;
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      // #region agent log
      _debugLogMM('H', 'loadDeepseek_success', {'activeModel': _activeModel.toString(), 'totalTimeMs': totalTime});
      // #endregion
      AppLogger.info('✅ [ModelManager] DeepSeek loaded successfully (${totalTime}ms)');
      return true;
    } catch (e) {
      AppLogger.error('❌ [ModelManager] Failed to load DeepSeek: $e');
      // Fall back to Gemma
      AppLogger.info('🔄 [ModelManager] Falling back to Gemma');
      _isLoading = false; // Reset before recursive call
      return await _loadGemma();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _unloadCurrentModel() async {
    if (_currentModel != null) {
      try {
        // flutter_gemma handles cleanup when new model is loaded
        _currentModel = null;
        AppLogger.debug('🗑️ [ModelManager] Previous model unloaded');
      } catch (e) {
        AppLogger.warning('⚠️ [ModelManager] Error unloading model: $e');
      }
    }
    _activeModel = ActiveModelType.none;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await _unloadCurrentModel();
    _returnToDeepseekAfterVision = false;
  }
}
