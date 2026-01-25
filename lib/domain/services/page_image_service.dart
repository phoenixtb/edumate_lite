import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger.dart';

/// Service for saving and retrieving compressed page images
class PageImageService {
  static PageImageService? _instance;
  static PageImageService get instance => _instance ??= PageImageService._();

  PageImageService._();

  String? _basePath;

  /// Get base path for page images
  Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    final appDir = await getApplicationDocumentsDirectory();
    _basePath = '${appDir.path}/page_images';
    return _basePath!;
  }

  /// Save a page image with compression
  /// Returns the relative path to the saved image
  Future<String?> savePageImage({
    required int materialId,
    required int pageNumber,
    required Uint8List imageBytes,
    int quality = 70,
  }) async {
    try {
      final base = await basePath;
      final dirPath = '$base/$materialId';
      final relativePath = 'page_images/$materialId/$pageNumber.jpg';

      // Create directory if needed
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes.isEmpty) {
        AppLogger.warning(
            '⚠️ [PAGE_IMAGE] Compression returned empty for page $pageNumber');
        return null;
      }

      // Save to file
      final filePath = '$base/$materialId/$pageNumber.jpg';
      final file = File(filePath);
      await file.writeAsBytes(compressedBytes);

      final originalKb = imageBytes.length / 1024;
      final compressedKb = compressedBytes.length / 1024;
      final ratio = (compressedKb / originalKb * 100).toStringAsFixed(1);

      AppLogger.debug(
        '💾 [PAGE_IMAGE] Saved page $pageNumber: '
        '${originalKb.toStringAsFixed(0)}KB → ${compressedKb.toStringAsFixed(0)}KB ($ratio%)',
      );

      return relativePath;
    } catch (e, stackTrace) {
      AppLogger.error('❌ [PAGE_IMAGE] Failed to save page $pageNumber', e, stackTrace);
      return null;
    }
  }

  /// Get the full path to a page image
  Future<String> getFullPath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  /// Check if a page image exists
  Future<bool> exists(String relativePath) async {
    final fullPath = await getFullPath(relativePath);
    return File(fullPath).exists();
  }

  /// Read a page image
  Future<Uint8List?> readPageImage(String relativePath) async {
    try {
      final fullPath = await getFullPath(relativePath);
      final file = File(fullPath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ [PAGE_IMAGE] Failed to read image: $relativePath', e);
      return null;
    }
  }

  /// Delete all images for a material
  Future<void> deleteForMaterial(int materialId) async {
    try {
      final base = await basePath;
      final dir = Directory('$base/$materialId');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        AppLogger.debug('🗑️ [PAGE_IMAGE] Deleted images for material $materialId');
      }
    } catch (e) {
      AppLogger.error('❌ [PAGE_IMAGE] Failed to delete images for material $materialId', e);
    }
  }

  /// Get total size of stored images for a material (in bytes)
  Future<int> getSizeForMaterial(int materialId) async {
    try {
      final base = await basePath;
      final dir = Directory('$base/$materialId');
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
