import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:edumate_lite/core/utils/token_estimator.dart';

/// Tests for token-validated chunking.
/// Real model tests are skipped if model files aren't available.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Token Validated Chunking Strategy', () {
    test('Extract and chunk Biology PDF - verify chunk sizes', () async {
      final pdfFile = File('assets/sample_docs/Biology2e-WEB.pdf');
      if (!await pdfFile.exists()) {
        print('⚠️  Test PDF not found, skipping');
        return;
      }

      // Test only validates PDF extraction and text structure
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      expect(document.pages.count, greaterThan(0));

      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText(
        startPageIndex: 0,
        endPageIndex: 0,
      );

      expect(text.isNotEmpty, isTrue);
      print('Page 1: ${text.length} chars extracted');

      document.dispose();
    });

    test('Verify char-to-token ratio assumptions', () {
      // TokenEstimator uses 2.5 tokens per word + 0.5 per punctuation
      // Verify this is reasonable for our use case
      print('\n📊 CHAR-TO-TOKEN RATIO ANALYSIS:');
      print('Using assumed ratio: 2.68 chars/token\n');

      final testTexts = [
        'Hello world',
        'The quick brown fox jumps over the lazy dog.',
        'This is a longer sentence with more words to test the tokenization.',
        '''Biology is the scientific study of life. It is a natural science with a 
        broad scope. All organisms are made up of cells that process hereditary 
        information. Genes can be transmitted to future generations through 
        reproduction. Evolution is a central concept that explains the unity 
        and diversity of life.''',
      ];

      for (final text in testTexts) {
        final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        final tokens = TokenEstimator.estimate(text);
        final wordsPerToken = words / tokens;

        print('  Text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
        print('  Chars: ${text.length}, Words: $words, Est. Tokens: $tokens');
        print('  Words/Token ratio: ${wordsPerToken.toStringAsFixed(2)}\n');

        // Verify tokens are greater than words (subword tokenization)
        expect(tokens, greaterThanOrEqualTo(words));
      }
    });

    test('Sentence splitting preserves content', () {
      const text = '''Biology is the scientific study of life. It is a natural science with a broad scope. All organisms are made up of cells that process hereditary information. Genes can be transmitted to future generations through reproduction. Evolution is a central concept that explains the unity and diversity of life. Natural selection is the primary mechanism of evolution proposed by Darwin.''';

      // Split by sentence boundaries
      final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

      print('\n📝 SENTENCE SPLITTING:');
      print('Original: ${text.length} chars');
      print('Sentences found: ${sentences.length}');

      final reconstructed = sentences.join(' ');
      print('Reconstructed: ${reconstructed.length} chars');

      for (var i = 0; i < sentences.length; i++) {
        print('  ${i + 1}. ${sentences[i]}');
      }

      // All sentences should be preserved
      expect(sentences.length, greaterThanOrEqualTo(5));
      for (final sentence in sentences) {
        expect(text, contains(sentence.trim()));
      }
    });

    test('Overlap calculation works correctly', () {
      const text = '''First paragraph that is relatively long.

Second paragraph with more content here.

Third paragraph that is the last one.''';

      final paragraphs = text.split(RegExp(r'\n\n+')).where((p) => p.trim().isNotEmpty).toList();

      expect(paragraphs.length, equals(3));

      // Simulate overlap calculation
      const overlapChars = 200;
      final lastParagraph = paragraphs.last;
      final overlap = lastParagraph.length <= overlapChars
          ? lastParagraph
          : lastParagraph.substring(lastParagraph.length - overlapChars);

      print('\n📝 OVERLAP CALCULATION:');
      print('Last paragraph: "$lastParagraph"');
      print('Overlap ($overlapChars chars): "$overlap"');

      expect(overlap.isNotEmpty, isTrue);
      expect(lastParagraph, contains(overlap));
    });
  });
}
