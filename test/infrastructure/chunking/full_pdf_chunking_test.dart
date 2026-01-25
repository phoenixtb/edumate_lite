import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Full PDF chunking test - processes entire Biology2e-WEB.pdf
/// This test validates the chunking strategy against a real large document.
/// 
/// Run with: flutter test test/infrastructure/chunking/full_pdf_chunking_test.dart -t 600
/// (600 second timeout for large PDF processing)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full PDF Chunking Test', () {
    // Strategy constants matching TokenValidatedChunkingStrategy
    const int targetChars = 4300;
    const int maxChars = 5100;
    const int maxTokens = 1900;
    const double charsPerToken = 2.68;
    const int overlapChars = 270;

    test('Process FULL Biology PDF - all pages', () async {
      final file = File('assets/sample_docs/Biology2e-WEB.pdf');
      if (!file.existsSync()) {
        print('⚠️ Test PDF not found at assets/sample_docs/Biology2e-WEB.pdf - skipping');
        return;
      }

      print('📄 Loading PDF...');
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final totalPages = document.pages.count;

      print('📄 PDF loaded: $totalPages pages');
      print('📊 Processing all pages (this may take a while)...\n');

      final textExtractor = PdfTextExtractor(document);
      final allChunks = <Map<String, dynamic>>[];
      var totalChars = 0;
      var totalParagraphs = 0;

      // Process in batches of 50 pages
      const batchSize = 50;
      var pagesProcessed = 0;

      for (var batchStart = 0; batchStart < totalPages; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize < totalPages)
            ? batchStart + batchSize
            : totalPages;

        final buffer = StringBuffer();

        for (var i = batchStart; i < batchEnd; i++) {
          try {
            final textLines = textExtractor.extractTextLines(
              startPageIndex: i,
              endPageIndex: i,
            );

            double lastY = 0;
            for (final line in textLines) {
              final text = line.text.trim();
              if (text.isEmpty) continue;

              // Paragraph break on vertical gap
              if (lastY > 0 && (line.bounds.top - lastY) > 15) {
                buffer.writeln();
                buffer.writeln();
              }
              buffer.writeln(text);
              lastY = line.bounds.bottom;
            }
            buffer.writeln();
          } catch (e) {
            // Some pages may fail to extract
            continue;
          }
        }

        pagesProcessed = batchEnd;

        // Process batch text
        final batchText = buffer.toString();
        if (batchText.trim().isEmpty) continue;

        totalChars += batchText.length;

        // Split into paragraphs
        final paragraphs = batchText
            .split(RegExp(r'\n\s*\n'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();

        totalParagraphs += paragraphs.length;

        // Apply chunking strategy
        final batchChunks = _chunkParagraphs(
          paragraphs,
          targetChars: targetChars,
          maxChars: maxChars,
          overlapChars: overlapChars,
          startPage: batchStart + 1,
        );

        allChunks.addAll(batchChunks);

        // Progress
        final progress = (pagesProcessed / totalPages * 100).toStringAsFixed(1);
        print('  Pages $batchStart-$batchEnd: ${paragraphs.length} paragraphs → ${batchChunks.length} chunks ($progress%)');
      }

      document.dispose();

      // Analyze results
      print('\n' + '=' * 60);
      print('📊 FULL PDF CHUNKING RESULTS');
      print('=' * 60);
      print('Total pages processed: $pagesProcessed');
      print('Total chars extracted: $totalChars');
      print('Total paragraphs: $totalParagraphs');
      print('Total chunks created: ${allChunks.length}');

      // Chunk statistics
      var minChars = double.maxFinite.toInt();
      var maxCharsFound = 0;
      var totalChunkChars = 0;
      var overLimitCount = 0;
      var overMaxTokensCount = 0;

      final tokenDistribution = <String, int>{
        '0-500': 0,
        '500-1000': 0,
        '1000-1500': 0,
        '1500-1900': 0,
        '1900+': 0,
      };

      for (final chunk in allChunks) {
        final chars = chunk['chars'] as int;
        final estimatedTokens = chunk['estimated_tokens'] as int;

        totalChunkChars += chars;
        if (chars < minChars) minChars = chars;
        if (chars > maxCharsFound) maxCharsFound = chars;

        if (chars > maxChars) overLimitCount++;
        if (estimatedTokens > maxTokens) overMaxTokensCount++;

        // Token distribution
        if (estimatedTokens < 500) {
          tokenDistribution['0-500'] = tokenDistribution['0-500']! + 1;
        } else if (estimatedTokens < 1000) {
          tokenDistribution['500-1000'] = tokenDistribution['500-1000']! + 1;
        } else if (estimatedTokens < 1500) {
          tokenDistribution['1000-1500'] = tokenDistribution['1000-1500']! + 1;
        } else if (estimatedTokens < 1900) {
          tokenDistribution['1500-1900'] = tokenDistribution['1500-1900']! + 1;
        } else {
          tokenDistribution['1900+'] = tokenDistribution['1900+']! + 1;
        }
      }

      print('\n📈 CHUNK STATISTICS:');
      print('  Min chunk: $minChars chars (~${(minChars / charsPerToken).round()} tokens)');
      print('  Max chunk: $maxCharsFound chars (~${(maxCharsFound / charsPerToken).round()} tokens)');
      print('  Avg chunk: ${(totalChunkChars / allChunks.length).round()} chars');
      print('  Target: $targetChars chars (~${(targetChars / charsPerToken).round()} tokens)');
      print('  Max limit: $maxChars chars (~$maxTokens tokens)');

      print('\n📊 TOKEN DISTRIBUTION:');
      for (final entry in tokenDistribution.entries) {
        final pct = (entry.value / allChunks.length * 100).toStringAsFixed(1);
        final bar = '█' * (entry.value * 30 ~/ allChunks.length);
        print('  ${entry.key.padRight(10)}: ${entry.value.toString().padLeft(4)} ($pct%) $bar');
      }

      print('\n⚠️  LIMIT VIOLATIONS:');
      print('  Over char limit ($maxChars): $overLimitCount');
      print('  Over token limit ($maxTokens est.): $overMaxTokensCount');

      // Sample chunks
      print('\n📝 SAMPLE CHUNKS (first 3):');
      for (var i = 0; i < 3 && i < allChunks.length; i++) {
        final chunk = allChunks[i];
        final preview = (chunk['content'] as String).substring(0, 100).replaceAll('\n', ' ');
        print('  Chunk ${i + 1}: ${chunk['chars']} chars, ~${chunk['estimated_tokens']} tokens');
        print('    Preview: "$preview..."');
      }

      // Assertions
      expect(allChunks.length, greaterThan(100),
          reason: 'Should create many chunks from large PDF');
      expect(overLimitCount, equals(0),
          reason: 'No chunk should exceed char limit');
      expect(maxCharsFound, lessThanOrEqualTo(maxChars),
          reason: 'Max chunk should be within limit');

      print('\n✅ PASSED: All ${allChunks.length} chunks within limits!');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}

/// Chunk paragraphs using the same logic as TokenValidatedChunkingStrategy
List<Map<String, dynamic>> _chunkParagraphs(
  List<String> paragraphs, {
  required int targetChars,
  required int maxChars,
  required int overlapChars,
  required int startPage,
}) {
  const charsPerToken = 2.68;
  final chunks = <Map<String, dynamic>>[];

  var currentParagraphs = <String>[];
  var currentChars = 0;

  for (final paragraph in paragraphs) {
    final paragraphChars = paragraph.length;

    // Single paragraph too long?
    if (paragraphChars > maxChars) {
      // Save current
      if (currentParagraphs.isNotEmpty) {
        final content = currentParagraphs.join('\n\n');
        chunks.add({
          'content': content,
          'chars': content.length,
          'estimated_tokens': (content.length / charsPerToken).round(),
          'page': startPage,
        });
        currentParagraphs = [];
        currentChars = 0;
      }

      // Split by sentences
      final sentenceChunks = _splitBySentences(
        paragraph,
        targetChars: targetChars,
        maxChars: maxChars,
        startPage: startPage,
      );
      chunks.addAll(sentenceChunks);
      continue;
    }

    final newChars = currentChars + paragraphChars + 2;

    if (newChars > targetChars && currentParagraphs.isNotEmpty) {
      final content = currentParagraphs.join('\n\n');
      chunks.add({
        'content': content,
        'chars': content.length,
        'estimated_tokens': (content.length / charsPerToken).round(),
        'page': startPage,
      });

      // Overlap
      final lastPara = currentParagraphs.last;
      currentParagraphs = lastPara.length <= overlapChars
          ? [lastPara, paragraph]
          : [paragraph];
      currentChars = currentParagraphs.join('\n\n').length;
    } else {
      currentParagraphs.add(paragraph);
      currentChars = newChars;
    }
  }

  // Finalize
  if (currentParagraphs.isNotEmpty) {
    final content = currentParagraphs.join('\n\n');
    chunks.add({
      'content': content,
      'chars': content.length,
      'estimated_tokens': (content.length / charsPerToken).round(),
      'page': startPage,
    });
  }

  return chunks;
}

List<Map<String, dynamic>> _splitBySentences(
  String text, {
  required int targetChars,
  required int maxChars,
  required int startPage,
}) {
  const charsPerToken = 2.68;
  final chunks = <Map<String, dynamic>>[];

  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.trim().isNotEmpty)
      .toList();

  var currentSentences = <String>[];
  var currentChars = 0;

  for (final sentence in sentences) {
    final sentenceChars = sentence.length;

    // Single sentence too long? Split by words
    if (sentenceChars > maxChars) {
      if (currentSentences.isNotEmpty) {
        final content = currentSentences.join(' ');
        chunks.add({
          'content': content,
          'chars': content.length,
          'estimated_tokens': (content.length / charsPerToken).round(),
          'page': startPage,
        });
        currentSentences = [];
        currentChars = 0;
      }

      // Split by words
      final wordChunks = _splitByWords(
        sentence,
        targetChars: targetChars,
        startPage: startPage,
      );
      chunks.addAll(wordChunks);
      continue;
    }

    final newChars = currentChars + sentenceChars + 1;

    if (newChars > targetChars && currentSentences.isNotEmpty) {
      final content = currentSentences.join(' ');
      chunks.add({
        'content': content,
        'chars': content.length,
        'estimated_tokens': (content.length / charsPerToken).round(),
        'page': startPage,
      });
      currentSentences = [sentence];
      currentChars = sentenceChars;
    } else {
      currentSentences.add(sentence);
      currentChars = newChars;
    }
  }

  if (currentSentences.isNotEmpty) {
    final content = currentSentences.join(' ');
    chunks.add({
      'content': content,
      'chars': content.length,
      'estimated_tokens': (content.length / charsPerToken).round(),
      'page': startPage,
    });
  }

  return chunks;
}

List<Map<String, dynamic>> _splitByWords(
  String text, {
  required int targetChars,
  required int startPage,
}) {
  const charsPerToken = 2.68;
  final chunks = <Map<String, dynamic>>[];

  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  var currentWords = <String>[];
  var currentChars = 0;

  for (final word in words) {
    final wordChars = word.length + 1;
    final newChars = currentChars + wordChars;

    if (newChars > targetChars && currentWords.isNotEmpty) {
      final content = currentWords.join(' ');
      chunks.add({
        'content': content,
        'chars': content.length,
        'estimated_tokens': (content.length / charsPerToken).round(),
        'page': startPage,
      });

      // Overlap
      final overlapCount = (currentWords.length * 0.1).ceil().clamp(3, 10);
      final overlap = currentWords.sublist(currentWords.length - overlapCount);
      currentWords = [...overlap, word];
      currentChars = currentWords.join(' ').length;
    } else {
      currentWords.add(word);
      currentChars = newChars;
    }
  }

  if (currentWords.isNotEmpty) {
    final content = currentWords.join(' ');
    chunks.add({
      'content': content,
      'chars': content.length,
      'estimated_tokens': (content.length / charsPerToken).round(),
      'page': startPage,
    });
  }

  return chunks;
}


