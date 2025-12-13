import 'dart:typed_data';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/message.dart' as gemma_msg;
import 'package:image/image.dart' as img;
import '../../core/constants/app_constants.dart';
import '../../infrastructure/ai/gemma_session_manager.dart';

/// Centralized Vision Service
/// Handles all image-related AI operations: OCR, analysis, Q&A
/// Uses GemmaSessionManager to coordinate with inference provider
class VisionService {
  VisionService._();
  static final VisionService instance = VisionService._();

  static const _sessionUser = 'VisionService';
  
  /// Check if vision model is available
  bool get isReady => FlutterGemma.hasActiveModel();
  
  /// Check if currently processing (via shared manager)
  bool get isBusy => GemmaSessionManager.instance.isBusy;

  /// Extract text from image (OCR)
  /// Used for: handwritten notes, image materials, PDF figures
  Future<String> extractText(Uint8List imageBytes) async {
    if (!isReady) {
      return '[Vision model not loaded - Load models from home screen]';
    }

    const prompt = '''Extract ALL text from this image exactly as shown.
Preserve the structure:
- Headings and subheadings
- Paragraphs and line breaks
- Lists (numbered or bulleted)
- Tables (format as markdown)
- Mathematical equations (use LaTeX notation)

Return ONLY the extracted text, no commentary or descriptions.''';

    return _processImage(imageBytes, prompt);
  }

  /// Analyze/describe an image
  /// Used for: diagram understanding, chart explanation
  Future<String> analyzeImage(
    Uint8List imageBytes, {
    String? context,
  }) async {
    if (!isReady) {
      return '[Vision model not loaded - Load models from home screen]';
    }

    final contextPart = context != null && context.isNotEmpty
        ? '\n\nRelevant context from study materials:\n$context'
        : '';

    final prompt = '''Analyze this image and provide a clear explanation.

If it's a diagram, chart, or figure:
1. Describe what it shows
2. Explain the key components
3. Describe any relationships or processes shown
4. Highlight important details a student should understand

Use simple language suitable for students.$contextPart''';

    return _processImage(imageBytes, prompt);
  }

  /// Answer a question about an image
  /// Used for: chat image attachments
  Stream<String> answerQuestion(
    Uint8List imageBytes,
    String question, {
    String? context,
  }) async* {
    if (!isReady) {
      yield '[Vision model not loaded - Load models from home screen]';
      return;
    }

    // Acquire shared session lock
    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 60),
    );
    
    if (!acquired) {
      yield '[AI is busy with another request. Please wait and try again.]';
      return;
    }

    try {
      final processedBytes = await _prepareImage(imageBytes);

      final contextPart = context != null && context.isNotEmpty
          ? '\n\nRelevant context from study materials:\n$context'
          : '';

      final prompt = '''$question$contextPart

Provide a clear, educational answer based on what you see in the image.
Use simple language suitable for students.''';

      final model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        supportImage: true,
      );

      final session = await model.createSession(
        enableVisionModality: true,
        temperature: AppConstants.inferenceTemperature,
        topK: AppConstants.inferenceSamplingTopK,
      );

      await session.addQueryChunk(
        gemma_msg.Message.withImage(
          text: prompt,
          imageBytes: processedBytes,
        ),
      );

      final responseStream = session.getResponseAsync();

      await for (final chunk in responseStream) {
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }

      await session.close();
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Previous invocation still processing')) {
        // Force release if we get this error - something is stuck
        GemmaSessionManager.instance.forceRelease();
        yield '[AI session error. Please try again.]';
      } else {
        yield '[Error processing image: $e]';
      }
    } finally {
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  /// Internal: Process image and get complete response
  Future<String> _processImage(Uint8List imageBytes, String prompt) async {
    // Acquire shared session lock
    final acquired = await GemmaSessionManager.instance.acquire(
      _sessionUser,
      timeout: const Duration(seconds: 60),
    );
    
    if (!acquired) {
      return '[AI is busy with another request. Please wait and try again.]';
    }

    try {
      final processedBytes = await _prepareImage(imageBytes);

      final model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        supportImage: true,
      );

      final session = await model.createSession(
        enableVisionModality: true,
        temperature: AppConstants.inferenceTemperature,
        topK: AppConstants.inferenceSamplingTopK,
      );

      await session.addQueryChunk(
        gemma_msg.Message.withImage(
          text: prompt,
          imageBytes: processedBytes,
        ),
      );

      final buffer = StringBuffer();
      final stream = session.getResponseAsync();

      await for (final chunk in stream) {
        buffer.write(chunk);
      }

      await session.close();

      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : '[No content detected in image]';
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Previous invocation still processing')) {
        // Force release if we get this error - something is stuck
        GemmaSessionManager.instance.forceRelease();
        return '[AI session error. Please try again.]';
      }
      return '[Failed to process image: $e]';
    } finally {
      GemmaSessionManager.instance.release(_sessionUser);
    }
  }

  /// Prepare image: resize if too large
  Future<Uint8List> _prepareImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      // Resize if too large (max 1024px on longest edge)
      const maxDimension = 1024;
      if (image.width > maxDimension || image.height > maxDimension) {
        final resized = img.copyResize(
          image,
          width: image.width > image.height ? maxDimension : null,
          height: image.height >= image.width ? maxDimension : null,
        );
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }

      return bytes;
    } catch (e) {
      return bytes;
    }
  }
}
