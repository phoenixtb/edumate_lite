import 'package:flutter_test/flutter_test.dart';
import 'package:edumate_lite/core/utils/token_estimator.dart';

void main() {
  group('TokenEstimator', () {
    test('estimate returns 0 for empty string', () {
      expect(TokenEstimator.estimate(''), 0);
    });

    test('estimate calculates tokens for simple text', () {
      const text = 'Hello world';
      final tokens = TokenEstimator.estimate(text);
      expect(tokens, greaterThan(0));
      // 2 words * 2.5 = 5
      expect(tokens, 5);
    });

    test('estimate includes punctuation', () {
      const text = 'Hello, world!';
      final tokens = TokenEstimator.estimate(text);
      // 2 words * 2.5 + 2 punctuation * 0.5 = 5 + 1 = 6
      expect(tokens, 6);
    });

    test('fitsInLimit returns true when under limit', () {
      const text = 'Short text';
      expect(TokenEstimator.fitsInLimit(text, 100), isTrue);
    });

    test('fitsInLimit returns false when over limit', () {
      const text = 'This is a longer text with many words';
      expect(TokenEstimator.fitsInLimit(text, 5), isFalse);
    });

    test('truncateToLimit does not modify text within limit', () {
      const text = 'Short text';
      expect(TokenEstimator.truncateToLimit(text, 100), text);
    });

    test('truncateToLimit truncates text over limit', () {
      const text = 'This is a much longer text that needs truncation';
      final truncated = TokenEstimator.truncateToLimit(text, 5);
      expect(truncated.length, lessThan(text.length));
    });

    test('estimateBatch calculates total tokens for multiple texts', () {
      const texts = ['Hello world', 'Another sentence', 'Final text'];
      final total = TokenEstimator.estimateBatch(texts);
      expect(total, greaterThan(0));
      
      // Verify it matches sum of individual estimates
      final expected = texts.fold(0, (sum, text) => sum + TokenEstimator.estimate(text));
      expect(total, expected);
    });

    test('estimate handles multiple spaces correctly', () {
      const text = 'Hello    world';
      final tokens = TokenEstimator.estimate(text);
      expect(tokens, 5); // Still 2 words * 2.5
    });
  });
}

