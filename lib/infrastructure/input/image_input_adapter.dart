import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../domain/interfaces/input_source.dart';
import '../../domain/services/vision_service.dart';
import '../../core/errors/exceptions.dart';

/// Image input adapter
/// Uses vision model for text extraction (OCR)
class ImageInputAdapter implements InputSource {
  @override
  String get sourceType => 'image';

  @override
  String get displayName => 'Image';

  @override
  List<String> get supportedExtensions => ['.jpg', '.jpeg', '.png', '.webp'];

  @override
  bool canHandle(dynamic input) {
    if (input is String) {
      final lower = input.toLowerCase();
      return supportedExtensions.any((ext) => lower.endsWith(ext));
    }
    if (input is File) {
      final lower = input.path.toLowerCase();
      return supportedExtensions.any((ext) => lower.endsWith(ext));
    }
    if (input is Uint8List) {
      return true; // Assume raw bytes are valid image
    }
    return false;
  }

  @override
  Stream<ExtractionProgress> extractContent(dynamic input) async* {
    if (!canHandle(input)) {
      yield ExtractionProgress(
        progress: 0,
        error: 'Invalid input type. Expected image file or bytes.',
      );
      return;
    }

    try {
      // Load image bytes
      yield ExtractionProgress(progress: 0.1, currentPage: 'Loading image...');

      final Uint8List imageBytes;
      if (input is String) {
        final file = File(input);
        if (!await file.exists()) {
          yield ExtractionProgress(
            progress: 0,
            error: 'File not found: $input',
          );
          return;
        }
        imageBytes = await file.readAsBytes();
      } else if (input is File) {
        if (!await input.exists()) {
          yield ExtractionProgress(
            progress: 0,
            error: 'File not found: ${input.path}',
          );
          return;
        }
        imageBytes = await input.readAsBytes();
      } else if (input is Uint8List) {
        imageBytes = input;
      } else {
        throw FileException('Invalid input type');
      }

      // Process image (resize if needed)
      yield ExtractionProgress(
        progress: 0.3,
        currentPage: 'Processing image...',
      );

      await _processImage(imageBytes);

      yield ExtractionProgress(
        progress: 0.5,
        currentPage: 'Extracting text with AI...',
      );

      // Use vision model for OCR
      final extractedText = await _extractTextWithVision(imageBytes);

      yield ExtractionProgress(
        progress: 1.0,
        extractedText: extractedText,
        isComplete: true,
      );
    } catch (e) {
      yield ExtractionProgress(
        progress: 0,
        error: 'Failed to process image: $e',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getMetadata(dynamic input) async {
    try {
      final Uint8List imageBytes;
      String? filePath;

      if (input is String) {
        final file = File(input);
        imageBytes = await file.readAsBytes();
        filePath = input;
      } else if (input is File) {
        imageBytes = await input.readAsBytes();
        filePath = input.path;
      } else if (input is Uint8List) {
        imageBytes = input;
      } else {
        throw FileException('Invalid input type');
      }

      // Decode image to get dimensions
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw FileException('Failed to decode image');
      }

      final metadata = <String, dynamic>{
        'width': image.width,
        'height': image.height,
        'fileSize': imageBytes.length,
      };

      if (filePath != null) {
        metadata['fileName'] = filePath.split('/').last;
        metadata['filePath'] = filePath;
      }

      return metadata;
    } catch (e) {
      throw FileException('Failed to extract metadata: $e');
    }
  }

  /// Process image: resize if too large, optimize
  Future<Uint8List> _processImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw FileException('Failed to decode image');
      }

      // Resize if too large (max 1024px on longest edge)
      const maxDimension = 1024;
      if (image.width > maxDimension || image.height > maxDimension) {
        final resized = img.copyResize(
          image,
          width: image.width > image.height ? maxDimension : null,
          height: image.height > image.width ? maxDimension : null,
        );

        // Re-encode as JPEG
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }

      return bytes;
    } catch (e) {
      // If processing fails, return original
      return bytes;
    }
  }

  /// Extract text from image using VisionService
  Future<String> _extractTextWithVision(Uint8List imageBytes) async {
    return VisionService.instance.extractText(imageBytes);
  }
}
