import '../../domain/interfaces/vector_store.dart';
import '../../domain/entities/chunk.dart';
import '../../objectbox.g.dart';
import '../../core/errors/exceptions.dart' as app_exceptions;

/// ObjectBox implementation of VectorStore
class ObjectBoxVectorStore implements VectorStore {
  final Store _store;
  late final Box<Chunk> _chunkBox;

  ObjectBoxVectorStore(this._store) {
    _chunkBox = _store.box<Chunk>();
  }

  @override
  Future<int> store(Chunk chunk) async {
    try {
      return _chunkBox.put(chunk);
    } catch (e) {
      throw app_exceptions.StorageException('Failed to store chunk: $e');
    }
  }

  @override
  Future<List<int>> storeBatch(List<Chunk> chunks) async {
    try {
      return _chunkBox.putMany(chunks);
    } catch (e) {
      throw app_exceptions.StorageException('Failed to store chunks: $e');
    }
  }

  @override
  Future<List<ScoredChunk>> search(
    List<double> queryEmbedding, {
    int topK = 5,
    double threshold = 0.5,
    List<int>? materialIds,
  }) async {
    try {
      if (queryEmbedding.isEmpty) {
        throw app_exceptions.StorageException('Query embedding cannot be empty');
      }

      // Perform vector search using HNSW index
      final vectorQuery = _chunkBox
          .query(Chunk_.embedding.nearestNeighborsF32(queryEmbedding, topK * 2))
          .build();

      final results = vectorQuery.findWithScores();
      vectorQuery.close();

      // Filter by threshold and material IDs, then convert to ScoredChunk
      final scoredChunks = <ScoredChunk>[];
      for (final result in results) {
        if (result.score >= threshold) {
          // Check material filter if provided
          if (materialIds != null && materialIds.isNotEmpty) {
            final materialId = result.object.material.targetId;
            if (!materialIds.contains(materialId)) {
              continue;
            }
          }
          
          scoredChunks.add(
            ScoredChunk(
              chunk: result.object,
              score: result.score,
            ),
          );
          
          // Stop when we have enough results
          if (scoredChunks.length >= topK) {
            break;
          }
        }
      }

      return scoredChunks;
    } catch (e) {
      throw app_exceptions.StorageException('Vector search failed: $e');
    }
  }

  @override
  Future<void> deleteByMaterial(int materialId) async {
    try {
      final query = _chunkBox
          .query(Chunk_.material.equals(materialId))
          .build();
      
      query.remove();
      query.close();
    } catch (e) {
      throw app_exceptions.StorageException('Failed to delete chunks: $e');
    }
  }

  @override
  Future<Chunk?> getById(int id) async {
    try {
      return _chunkBox.get(id);
    } catch (e) {
      throw app_exceptions.StorageException('Failed to get chunk: $e');
    }
  }

  /// Get chunk by ID synchronously (for quick lookups)
  Chunk? getChunkById(int id) {
    try {
      return _chunkBox.get(id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Chunk>> getByMaterial(int materialId) async {
    try {
      final query = _chunkBox
          .query(Chunk_.material.equals(materialId))
          .build();
      
      final chunks = query.find();
      query.close();
      return chunks;
    } catch (e) {
      throw app_exceptions.StorageException('Failed to get chunks by material: $e');
    }
  }

  /// Get all chunks (for dev tools)
  Future<List<Chunk>> getAllChunks() async {
    try {
      return _chunkBox.getAll();
    } catch (e) {
      throw app_exceptions.StorageException('Failed to get all chunks: $e');
    }
  }
}

