import 'package:flutter_test/flutter_test.dart';
import 'package:edumate_lite/domain/interfaces/embedding_provider.dart';
import 'package:edumate_lite/domain/interfaces/vector_store.dart';
import 'package:edumate_lite/domain/entities/chunk.dart';
import 'package:edumate_lite/domain/entities/material.dart';

/// Mock implementations for testing
class MockEmbeddingProvider implements EmbeddingProvider {
  @override
  String get modelId => 'mock';

  @override
  int get dimension => 768;

  @override
  bool get isReady => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<double>> embed(String text) async {
    return List.generate(768, (i) => i / 768);
  }

  @override
  Future<List<double>> embedQuery(String query) async {
    return List.generate(768, (i) => i / 768);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    return [for (final text in texts) await embed(text)];
  }

  @override
  Future<void> dispose() async {}
}

class MockVectorStore implements VectorStore {
  final List<Chunk> _chunks = [];

  void addChunk(Chunk chunk) {
    _chunks.add(chunk);
  }

  @override
  Future<int> store(Chunk chunk) async => 1;

  @override
  Future<List<int>> storeBatch(List<Chunk> chunks) async => [1, 2, 3];

  @override
  Future<List<ScoredChunk>> search(
    List<double> queryEmbedding, {
    int topK = 5,
    double threshold = 0.5,
    List<int>? materialIds,
  }) async {
    return _chunks
        .map((c) => ScoredChunk(chunk: c, score: 0.85))
        .take(topK)
        .toList();
  }

  @override
  Future<void> deleteByMaterial(int materialId) async {}

  @override
  Future<Chunk?> getById(int id) async => null;

  @override
  Future<List<Chunk>> getByMaterial(int materialId) async => _chunks;
}

void main() {
  group('RagEngine Components', () {
    late MockEmbeddingProvider embeddingProvider;
    late MockVectorStore vectorStore;

    setUp(() {
      embeddingProvider = MockEmbeddingProvider();
      vectorStore = MockVectorStore();

      // Add test chunks
      final material = Material(title: 'Test', sourceType: 'pdf');
      material.id = 1;

      for (var i = 0; i < 5; i++) {
        final chunk = Chunk(
          content: 'Test content $i about biology and cells.',
          sequenceIndex: i,
        )..material.target = material;
        vectorStore.addChunk(chunk);
      }
    });

    test('embedding provider returns correct dimension', () async {
      expect(embeddingProvider.dimension, equals(768));
      expect(embeddingProvider.isReady, isTrue);
    });

    test('embedding generates vector of correct size', () async {
      final embedding = await embeddingProvider.embed('test text');
      expect(embedding.length, equals(768));
    });

    test('vector store returns scored chunks', () async {
      final queryEmbedding = List.generate(768, (i) => i / 768.0);
      final results = await vectorStore.search(queryEmbedding, topK: 3);

      expect(results.length, equals(3));
      expect(results.first.score, equals(0.85));
      expect(results.first.chunk.content, contains('Test content'));
    });

    test('vector store respects topK limit', () async {
      final queryEmbedding = List.generate(768, (i) => i / 768.0);
      final results = await vectorStore.search(queryEmbedding, topK: 2);

      expect(results.length, equals(2));
    });

    test('vector store can filter by materialIds', () async {
      final queryEmbedding = List.generate(768, (i) => i / 768.0);
      final results = await vectorStore.search(
        queryEmbedding,
        topK: 5,
        materialIds: [1],
      );

      expect(results.length, greaterThan(0));
    });

    test('empty vector store returns no results', () async {
      final emptyStore = MockVectorStore();
      final queryEmbedding = List.generate(768, (i) => i / 768.0);
      final results = await emptyStore.search(queryEmbedding);

      expect(results, isEmpty);
    });

    test('batch embedding works correctly', () async {
      final texts = ['text one', 'text two', 'text three'];
      final embeddings = await embeddingProvider.embedBatch(texts);

      expect(embeddings.length, equals(3));
      for (final emb in embeddings) {
        expect(emb.length, equals(768));
      }
    });

    test('chunks have proper material association', () async {
      final queryEmbedding = List.generate(768, (i) => i / 768.0);
      final results = await vectorStore.search(queryEmbedding, topK: 1);

      expect(results.first.chunk.material.target, isNotNull);
      expect(results.first.chunk.material.target!.title, equals('Test'));
    });
  });
}
