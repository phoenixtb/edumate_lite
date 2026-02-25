import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/message.dart' as gemma_msg;
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../config/service_locator.dart';
import '../../stores/app_store.dart';
import '../../infrastructure/ai/model_manager.dart';
import '../../infrastructure/ai/gemma_session_manager.dart';

/// Routes inference requests to appropriate model based on:
/// 1. Input type (image → Gemma, text → Phi-4 if available)
/// 2. User preference (can override to always use Gemma)
/// 
/// Handles model switching when needed (vision requires Gemma).
class InferenceRouter {
  static const _sessionUser = 'InferenceRouter';

  /// Callback for showing vision switch dialog
  /// Set this from the UI layer
  static Future<bool> Function(BuildContext context)? showVisionSwitchDialog;

  /// Initialize and load the appropriate model based on preference
  Future<void> initialize() async {
    await ModelManager.instance.loadInitialModel();
  }

  // #region agent log
  static void _debugLog(String hypId, String msg, Map<String, dynamic> data) {
    AppLogger.debug('🔬 [DEBUG:$hypId] $msg: ${jsonEncode(data)}');
  }
  // #endregion

  /// Generate response for text query
  /// Uses Chat API for DeepSeek compatibility
  Stream<String> generate({
    required String systemPrompt,
    required String context,
    required String query,
    List<dynamic>? conversationHistory,
  }) async* {
    // #region agent log
    _debugLog('A', 'generate_entry', {'systemPromptLen': systemPrompt.length, 'contextLen': context.length, 'queryLen': query.length});
    // #endregion
    
    // Ensure correct model is loaded for text
    await ModelManager.instance.ensureModelForText();
    
    final activeModel = ModelManager.instance.activeModel;
    final isQwen = activeModel == ActiveModelType.qwen || activeModel == ActiveModelType.deepseek || activeModel == ActiveModelType.phi4;
    final modelName = isQwen ? 'Qwen 2.5' : 'Gemma 3n E2B';
    AppLogger.info('🤖 [INFERENCE] Using model: $modelName (activeModel=$activeModel, isQwen=$isQwen)');
    
    // #region agent log
    _debugLog('A,D', 'after_ensureModel', {'activeModel': activeModel.toString(), 'isQwen': isQwen, 'modelName': modelName, 'currentModelNull': ModelManager.instance.currentModel == null, 'isLoading': ModelManager.instance.isLoading});
    // #endregion

    // Acquire session lock
    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 120),
    );

    if (!acquired) {
      yield 'AI is busy. Please wait and try again.';
      return;
    }
    
    // #region agent log
    _debugLog('B', 'session_acquired', {'lockHolder': GemmaSessionManager.instance.currentUser});
    // #endregion

    InferenceChat? chat;
    try {
      final model = ModelManager.instance.currentModel;
      if (model == null) {
        // #region agent log
        _debugLog('D', 'model_null', {'activeModel': activeModel.toString()});
        // #endregion
        yield 'Model not loaded. Please try again.';
        return;
      }

      // Qwen: lower temp for focused, factual responses
      // Higher values cause "blabbering" - use conservative settings
      final temperature = isQwen ? 0.5 : AppConstants.inferenceTemperature;
      final topK = isQwen ? 20 : AppConstants.inferenceSamplingTopK;
      final topP = isQwen ? 0.8 : 0.9;
      
      // #region agent log
      _debugLog('E', 'before_createChat', {'temp': temperature, 'topK': topK, 'topP': topP, 'tokenBuffer': 256});
      // #endregion

      // Use Chat API (works better for DeepSeek)
      chat = await model.createChat(
        temperature: temperature,
        topK: topK,
        topP: topP,
        tokenBuffer: 256,
      );
      
      // #region agent log
      _debugLog('E', 'after_createChat', {'chatCreated': chat != null});
      // #endregion

      var fullPrompt = _buildPrompt(
        systemPrompt: systemPrompt,
        context: context,
        query: query,
        conversationHistory: conversationHistory,
      );
      
      // Qwen has smaller context (1280 tokens). Truncate if needed.
      // Rough estimate: 1 token ≈ 4 chars, so 1280 tokens ≈ 5000 chars
      // Leave room for response: max input ≈ 4000 chars
      const maxPromptChars = 4000;
      if (isQwen && fullPrompt.length > maxPromptChars) {
        AppLogger.warning('⚠️ [INFERENCE] Truncating prompt for Qwen: ${fullPrompt.length} -> $maxPromptChars');
        // Truncate the context portion, keep query and system prompt
        final contextStart = fullPrompt.indexOf('CONTEXT FROM STUDY MATERIALS:');
        final contextEnd = fullPrompt.indexOf("STUDENT'S QUESTION:");
        if (contextStart != -1 && contextEnd != -1 && contextEnd > contextStart) {
          final beforeContext = fullPrompt.substring(0, contextStart);
          final afterContext = fullPrompt.substring(contextEnd);
          final availableForContext = maxPromptChars - beforeContext.length - afterContext.length - 100;
          if (availableForContext > 200) {
            final contextSection = fullPrompt.substring(contextStart, contextEnd);
            final truncatedContext = contextSection.length > availableForContext 
                ? '${contextSection.substring(0, availableForContext)}...\n[Context truncated]\n' 
                : contextSection;
            fullPrompt = '$beforeContext$truncatedContext$afterContext';
          }
        }
      }
      
      // #region agent log
      _debugLog('C', 'before_addQuery', {'promptLength': fullPrompt.length, 'isQwen': isQwen, 'truncated': fullPrompt.length <= maxPromptChars});
      // #endregion

      // Add query with isUser flag
      await chat.addQuery(gemma_msg.Message.text(text: fullPrompt, isUser: true));
      
      // #region agent log
      _debugLog('C', 'after_addQuery', {'success': true});
      // #endregion

      final responseStream = chat.generateChatResponseAsync();
      final buffer = StringBuffer();
      String? lastToken;
      int repeatCount = 0;
      bool stopped = false;
      
      // #region agent log
      _debugLog('B', 'stream_start', {'streamStarted': true});
      // #endregion
      
      await for (final response in responseStream) {
        if (stopped) continue;
        
        // Extract token from response - try multiple approaches
        String token = '';
        if (response is TextResponse) {
          token = response.token;
        } else {
          // Non-text response - skip silently
          continue;
        }
        
        if (token.isNotEmpty) {
          // Detect repetition for short tokens
          if (token == lastToken && token.length < 5) {
            repeatCount++;
            if (repeatCount >= 5) {
              AppLogger.warning('⚠️ [INFERENCE] Detected repetition, stopping');
              stopped = true;
              try { await chat.stopGeneration(); } catch (_) {}
              continue;
            }
          } else {
            repeatCount = 0;
            lastToken = token;
          }
          
          buffer.write(token);
          yield token;
          
          // Safety limit
          if (buffer.length > 4000) {
            AppLogger.warning('⚠️ [INFERENCE] Output too long, stopping');
            stopped = true;
            try { await chat.stopGeneration(); } catch (_) {}
            continue;
          }
        }
      }
      
      // #region agent log
      _debugLog('B', 'stream_end', {'bufferLength': buffer.length});
      // #endregion
      
      AppLogger.debug('✅ [INFERENCE] Stream fully drained (${buffer.length} chars)');
      
      // #region agent log
      // Detect TFLite failure (empty response indicates GATHER_ND or similar op failure)
      if (buffer.isEmpty) {
        _debugLog('F', 'empty_response_detected', {'isQwen': isQwen});
        AppLogger.warning('⚠️ [INFERENCE] Empty response detected - possible TFLite op failure');
        yield 'Model inference failed. The AI model may not be compatible with this device.';
      }
      // #endregion
    } catch (e) {
      AppLogger.error('❌ [INFERENCE] Generation failed: $e');
      yield 'Generation failed: $e';
    } finally {
      // #region agent log
      _debugLog('B', 'finally_start', {'chatNotNull': chat != null});
      // #endregion
      
      // Force stop and cleanup the chat session
      if (chat != null) {
        try {
          await chat.stopGeneration();
          // #region agent log
          _debugLog('B', 'stopGeneration_called', {'success': true});
          // #endregion
        } catch (e) {
          // #region agent log
          _debugLog('B', 'stopGeneration_error', {'error': e.toString()});
          // #endregion
        }
      }
      
      // Wait for native cleanup
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // #region agent log
      _debugLog('B', 'releasing_lock', {});
      // #endregion
      
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  /// Generate response for vision query (requires Gemma)
  /// 
  /// [context] - BuildContext for showing dialog if model switch needed
  /// Returns null if user declined model switch
  Stream<String>? generateWithImage({
    required String systemPrompt,
    required Uint8List imageBytes,
    required String query,
    required BuildContext context,
  }) {
    // Check if we need to switch models
    final activeModel = ModelManager.instance.activeModel;
    
    if (activeModel != ActiveModelType.gemma) {
      // Need to switch to Gemma for vision
      return _handleVisionWithModelSwitch(
        systemPrompt: systemPrompt,
        imageBytes: imageBytes,
        query: query,
        context: context,
      );
    }

    return _generateVision(
      systemPrompt: systemPrompt,
      imageBytes: imageBytes,
      query: query,
    );
  }

  Stream<String> _handleVisionWithModelSwitch({
    required String systemPrompt,
    required Uint8List imageBytes,
    required String query,
    required BuildContext context,
  }) async* {
    // Ask user if they want to switch
    final confirmed = await _showSwitchDialog(context);
    
    if (!confirmed) {
      yield 'Image analysis cancelled. Gemma model is required for vision tasks.';
      return;
    }

    // Switch to Gemma, marking to return to Phi-4 later
    AppLogger.info('🔄 [INFERENCE] Switching to Gemma for vision...');
    final switched = await ModelManager.instance.switchToGemma(markReturnToDeepseek: true);
    
    if (!switched) {
      yield 'Failed to switch to Gemma model. Please try again.';
      return;
    }

    yield* _generateVision(
      systemPrompt: systemPrompt,
      imageBytes: imageBytes,
      query: query,
    );
  }

  Stream<String> _generateVision({
    required String systemPrompt,
    required Uint8List imageBytes,
    required String query,
  }) async* {
    AppLogger.info('🤖 [INFERENCE] Using model: Gemma 3n E2B (vision)');

    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 120),
    );

    if (!acquired) {
      yield 'AI is busy. Please wait and try again.';
      return;
    }

    InferenceModelSession? session;
    try {
      final model = ModelManager.instance.currentModel;
      if (model == null) {
        yield 'Model not loaded. Please try again.';
        return;
      }

      session = await model.createSession(
        enableVisionModality: true,
      );

      await session.addQueryChunk(
        gemma_msg.Message.withImage(
          text: '$systemPrompt\n\n$query',
          imageBytes: imageBytes,
        ),
      );

      final responseStream = session.getResponseAsync();
      await for (final chunk in responseStream) {
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } catch (e) {
      AppLogger.error('❌ [INFERENCE] Vision generation failed: $e');
      yield 'Vision analysis failed: $e';
    } finally {
      if (session != null) {
        try {
          await session.close();
        } catch (_) {}
      }
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  Future<bool> _showSwitchDialog(BuildContext context) async {
    if (showVisionSwitchDialog != null) {
      return await showVisionSwitchDialog!(context);
    }
    
    // Default dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to Gemma?'),
        content: const Text(
          'Image analysis requires the Gemma model. '
          'Switch now? (Will return to Phi-4 for next text query)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _buildPrompt({
    required String systemPrompt,
    required String context,
    required String query,
    List<dynamic>? conversationHistory,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(systemPrompt);
    buffer.writeln();

    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      buffer.writeln('CONVERSATION HISTORY:');
      for (final msg in conversationHistory) {
        if (msg.role != null && msg.content != null) {
          buffer.writeln('${msg.role.toString().toUpperCase()}: ${msg.content}');
        }
      }
      buffer.writeln();
    }

    buffer.writeln('CONTEXT FROM STUDY MATERIALS:');
    buffer.writeln('---');
    buffer.writeln(context);
    buffer.writeln('---');
    buffer.writeln();

    buffer.writeln("STUDENT'S QUESTION: $query");
    buffer.writeln();
    buffer.writeln('YOUR RESPONSE:');

    return buffer.toString();
  }

  /// Get currently active model name
  String get activeModelName {
    switch (ModelManager.instance.activeModel) {
      case ActiveModelType.qwen:
      case ActiveModelType.phi4:
      case ActiveModelType.deepseek:
        return 'Qwen 2.5';
      case ActiveModelType.gemma:
        return 'Gemma 3n E2B';
      case ActiveModelType.none:
        return 'None';
    }
  }

  /// Check if any model is ready for inference
  bool get isReady => ModelManager.instance.currentModel != null;

  /// Check if Qwen is available
  Future<bool> isQwenAvailable() async {
    return await ModelManager.instance.isQwenInstalled();
  }

  /// Refresh model state after download/delete
  Future<void> refreshModelState() async {
    final qwenAvailable = await isQwenAvailable();
    final appStore = getIt<AppStore>();
    appStore.setPhi4ModelReady(qwenAvailable); // Reuse flag for Qwen
    AppLogger.debug('🔄 [INFERENCE] Model state refreshed: qwenAvailable=$qwenAvailable');
  }
}
