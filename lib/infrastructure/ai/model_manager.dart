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
  deepseek, // Deprecated - use qwen instead
  qwen,
}

/// Manages model loading/unloading for inference
/// 
/// flutter_gemma only supports ONE active model at a time.
/// This manager handles switching between Gemma and Qwen 2.5.
class ModelManager {
  ModelManager._();
  static final ModelManager instance = ModelManager._();

  ActiveModelType _activeModel = ActiveModelType.none;
  InferenceModel? _currentModel;
  bool _isLoading = false;
  bool _returnToQwenAfterVision = false;

  ActiveModelType get activeModel => _activeModel;
  InferenceModel? get currentModel => _currentModel;
  bool get isLoading => _isLoading;
  bool get shouldReturnToPhi4 => _returnToQwenAfterVision; // Backwards compat

  /// Check if Qwen is installed
  Future<bool> isQwenInstalled() async {
    try {
      final models = await FlutterGemma.listInstalledModels();
      return models.any((m) => m.toLowerCase().contains('qwen'));
    } catch (e) {
      return false;
    }
  }
  
  /// Backwards compat - check if "DeepSeek" is installed (now checks Qwen)
  Future<bool> isDeepseekInstalled() async {
    return isQwenInstalled();
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
    final qwenAvailable = await isQwenInstalled();
    
    if (qwenAvailable) {
      appStore.setPhi4ModelReady(true); // Reuse the flag for Qwen
    }

    if (qwenAvailable && appStore.preferPhi4ForText) {
      AppLogger.info('🚀 [ModelManager] Loading Qwen 2.5 (user preference)');
      await _loadQwen();
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
    
    // Remember to return to Qwen later
    if (markReturnToDeepseek && _activeModel == ActiveModelType.qwen) {
      _returnToQwenAfterVision = true;
      AppLogger.debug('📌 [ModelManager] Will return to Qwen after vision task');
    }

    await _unloadCurrentModel();
    return await _loadGemma();
  }

  /// Switch to Qwen 2.5 (for better text reasoning)
  Future<bool> switchToQwen() async {
    if (_activeModel == ActiveModelType.qwen) {
      AppLogger.debug('✅ [ModelManager] Qwen already active');
      return true;
    }

    if (_isLoading) {
      AppLogger.warning('⚠️ [ModelManager] Model loading in progress');
      return false;
    }

    final qwenAvailable = await isQwenInstalled();
    if (!qwenAvailable) {
      AppLogger.warning('⚠️ [ModelManager] Qwen not installed');
      return false;
    }

    AppLogger.info('🔄 [ModelManager] Switching to Qwen 2.5...');
    await _unloadCurrentModel();
    return await _loadQwen();
  }
  
  /// Backwards compat - switch to DeepSeek (actually loads Qwen)
  Future<bool> switchToDeepseek() async {
    return await switchToQwen();
  }

  /// Backwards compat - switch to Phi-4 (actually loads Qwen)
  Future<bool> switchToPhi4() async {
    return await switchToQwen();
  }

  /// Return to Qwen if flagged (after vision task)
  Future<void> returnToPhi4IfNeeded() async {
    if (!_returnToQwenAfterVision) return;
    
    final appStore = getIt<AppStore>();
    if (!appStore.preferPhi4ForText) {
      _returnToQwenAfterVision = false;
      return;
    }

    AppLogger.info('🔄 [ModelManager] Returning to Qwen (after vision)');
    _returnToQwenAfterVision = false;
    await switchToQwen();
  }

  /// Ensure correct model is loaded for text query
  Future<bool> ensureModelForText() async {
    final appStore = getIt<AppStore>();
    
    // Check if we need to return to Qwen
    if (_returnToQwenAfterVision && appStore.preferPhi4ForText) {
      AppLogger.info('🔄 [ModelManager] Switching back to Qwen for text');
      _returnToQwenAfterVision = false;
      return await switchToQwen();
    }
    
    // Check if preference matches active model
    if (appStore.preferPhi4ForText && appStore.isPhi4ModelReady) {
      if (_activeModel != ActiveModelType.qwen) {
        return await switchToQwen();
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
    _returnToQwenAfterVision = false;
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

  Future<bool> _loadQwen() async {
    _isLoading = true;
    final startTime = DateTime.now();
    // #region agent log
    _debugLogMM('H', 'loadQwen_start', {'time': startTime.toIso8601String(), 'prevActiveModel': _activeModel.toString()});
    // #endregion
    try {
      // Check if Qwen is already installed (on disk)
      final models = await FlutterGemma.listInstalledModels();
      final qwenName = models.firstWhere(
        (m) => m.toLowerCase().contains('qwen'),
        orElse: () => '',
      );
      
      // #region agent log
      _debugLogMM('H', 'installedModels', {'models': models, 'qwenName': qwenName, 'elapsedMs': DateTime.now().difference(startTime).inMilliseconds});
      // #endregion

      if (qwenName.isEmpty) {
        AppLogger.warning('⚠️ [ModelManager] Qwen not found in installed models');
        return await _loadGemma();
      }

      // CRITICAL: installModel() must be called to load model INTO MEMORY
      AppLogger.info('🔄 [ModelManager] Loading Qwen 2.5 into memory (this may take time)...');
      
      // #region agent log
      _debugLogMM('H', 'before_installModel', {'qwenName': qwenName, 'elapsedMs': DateTime.now().difference(startTime).inMilliseconds});
      // #endregion
      
      // Use fromBundled() to load from internal storage where the download was saved
      await FlutterGemma.installModel(
        modelType: ModelType.qwen,
      )
          .fromBundled(qwenName)
          .withProgress((progress) {
            if (progress.toInt() % 10 == 0) {
              AppLogger.debug('📦 [ModelManager] Qwen loading: ${progress.toInt()}%');
            }
          })
          .install();
      
      final installTime = DateTime.now().difference(startTime).inMilliseconds;
      // #region agent log
      _debugLogMM('H', 'after_installModel', {'installTimeMs': installTime});
      // #endregion
      AppLogger.info('📦 [ModelManager] Qwen install completed (${installTime}ms)');

      // #region agent log
      _debugLogMM('H', 'before_getActiveModel', {'tryingBackend': 'cpu', 'maxTokens': 1024, 'elapsedMs': DateTime.now().difference(startTime).inMilliseconds});
      // #endregion
      
      // Qwen uses CPU backend per flutter_gemma defaults
      _currentModel = await FlutterGemma.getActiveModel(
        maxTokens: 1024, // Qwen default
        supportImage: false,
        preferredBackend: PreferredBackend.cpu,
      );
      
      final getActiveTime = DateTime.now().difference(startTime).inMilliseconds;
      // #region agent log
      _debugLogMM('H', 'after_getActiveModel', {'modelNull': _currentModel == null, 'modelHashCode': _currentModel?.hashCode, 'getActiveTimeMs': getActiveTime});
      // #endregion

      // Wait for model to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_currentModel == null) {
        AppLogger.warning('⚠️ [ModelManager] Qwen model is null after load');
        return await _loadGemma();
      }

      _activeModel = ActiveModelType.qwen;
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      // #region agent log
      _debugLogMM('H', 'loadQwen_success', {'activeModel': _activeModel.toString(), 'totalTimeMs': totalTime});
      // #endregion
      AppLogger.info('✅ [ModelManager] Qwen 2.5 loaded successfully (${totalTime}ms)');
      return true;
    } catch (e) {
      AppLogger.error('❌ [ModelManager] Failed to load Qwen: $e');
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
    _returnToQwenAfterVision = false;
  }
}
