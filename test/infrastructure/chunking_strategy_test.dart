import 'package:flutter_test/flutter_test.dart';
import 'package:edumate_lite/infrastructure/chunking/educational_chunking_strategy.dart';
import 'package:edumate_lite/core/constants/app_constants.dart';

void main() {
  group('EducationalChunkingStrategy - Word Limit Tests', () {
    late EducationalChunkingStrategy strategy;

    setUp(() {
      strategy = EducationalChunkingStrategy();
    });

    test('respects targetChunkSize constant', () {
      expect(strategy.targetChunkSize, equals(AppConstants.targetChunkSizeTokens));
      expect(strategy.targetChunkSize, equals(1800));
    });

    test('word limits match expected values', () {
      // These are word-based limits used by EducationalChunkingStrategy
      // Production uses TokenValidatedChunkingStrategy with actual tokenizer
      expect(AppConstants.targetChunkWords, equals(1400));
      expect(AppConstants.maxChunkWords, equals(1500));
      expect(AppConstants.chunkOverlapWords, equals(115));
    });

    test('creates chunks from long text', () async {
      // 2000 words should create multiple chunks with 1400 word target
      final longText = List.generate(2000, (i) => 'word').join(' ');
      
      final chunks = await strategy.chunk(longText, {});
      
      expect(chunks.isNotEmpty, true);
      expect(chunks.length, greaterThan(1));
      
      // Verify chunks respect word limits
      for (final chunk in chunks) {
        final words = chunk.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        expect(
          words,
          lessThanOrEqualTo(AppConstants.maxChunkWords + 50), // small buffer for overlap
          reason: 'Chunk has $words words, should be <= ${AppConstants.maxChunkWords}',
        );
      }
    });

    test('creates multiple chunks for very long text', () async {
      // 3000 words with 1400 word target should create ~2-3 chunks
      final text = List.generate(3000, (i) => 'word$i').join(' ');
      
      final chunks = await strategy.chunk(text, {});
      
      expect(chunks.length, greaterThanOrEqualTo(2));
      
      print('Generated ${chunks.length} chunks from 3000 words');
      for (var i = 0; i < chunks.length; i++) {
        final words = chunks[i].content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        print('Chunk $i: $words words');
      }
    });

    test('splits long sections correctly', () async {
      // 1000 sentences * ~8 words = ~8000 words, should create multiple chunks
      final longSection = List.generate(1000, (i) => 
        'This is sentence number $i with some content. '
      ).join('');
      
      final chunks = await strategy.chunk(longSection, {});
      
      expect(chunks.length, greaterThan(1));
      
      // All chunks should respect word limits
      for (final chunk in chunks) {
        final words = chunk.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        expect(words, lessThanOrEqualTo(AppConstants.maxChunkWords + 100),
          reason: 'Chunk has $words words, should be <= ${AppConstants.maxChunkWords}');
      }
    });

    test('realistic PDF text creates reasonable chunks', () async {
      final realisticText = '''
Chapter 1: Introduction to Biology

Biology is the scientific study of life and living organisms. It encompasses various fields including molecular biology, genetics, ecology, and evolution.

Key Concepts:
- Cell theory: All living things are made of cells
- Evolution: Species change over time through natural selection
- Genetics: Heredity and variation in organisms
- Homeostasis: Maintenance of internal stability

The scope of biology ranges from microscopic molecules to entire ecosystems. Modern biology integrates knowledge from chemistry, physics, mathematics, and computer science to understand life processes.

Example 1: Cell Structure
A typical animal cell contains organelles such as the nucleus, mitochondria, endoplasmic reticulum, and Golgi apparatus. Each organelle performs specific functions essential for cell survival.

The cell membrane acts as a selective barrier, controlling what enters and exits the cell. This selective permeability is crucial for maintaining cellular homeostasis.
''';

      final chunks = await strategy.chunk(realisticText, {});
      
      print('\n=== Realistic PDF Text Test ===');
      print('Input words: ${realisticText.split(RegExp(r'\s+')).length}');
      print('Chunks generated: ${chunks.length}');
      
      // Short text should fit in one chunk
      expect(chunks.length, greaterThanOrEqualTo(1));
      
      for (var i = 0; i < chunks.length; i++) {
        final words = chunks[i].content.split(RegExp(r'\s+')).length;
        print('Chunk $i: $words words (type: ${chunks[i].chunkType})');
      }
    });
  });
}
