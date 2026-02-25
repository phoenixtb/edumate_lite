import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/chunk.dart';
import '../../../domain/entities/material.dart' as mat;
import '../../../infrastructure/database/objectbox_vector_store.dart';
import '../../../domain/services/keyword_extractor.dart';
import '../../../domain/services/semantic_keyword_extractor.dart';

/// Screen to test and compare rule-based vs semantic keyword extraction
class SemanticKeywordTestScreen extends StatefulWidget {
  final mat.Material material;

  const SemanticKeywordTestScreen({super.key, required this.material});

  @override
  State<SemanticKeywordTestScreen> createState() =>
      _SemanticKeywordTestScreenState();
}

class _SemanticKeywordTestScreenState extends State<SemanticKeywordTestScreen> {
  final ObjectBoxVectorStore _vectorStore = GetIt.I<ObjectBoxVectorStore>();

  List<Chunk> _chunks = [];
  bool _isLoading = true;
  String? _error;

  // Results per chunk
  final Map<int, _ChunkResult> _results = {};
  int? _processingChunkIndex;

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    try {
      final chunks = await _vectorStore.getByMaterial(widget.material.id);
      setState(() {
        _chunks = chunks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _processChunk(int index) async {
    if (_results.containsKey(index)) return; // Already processed

    setState(() => _processingChunkIndex = index);

    try {
      final chunk = _chunks[index];
      final text = chunk.content;

      // 1. Rule-based extraction
      final ruleKeywords =
          KeywordExtractor.instance.extractKeywords(text, maxKeywords: 10);

      // 2. Semantic extraction
      final semanticExtractor = SemanticKeywordExtractor.instance;
      final semanticKeywords = await semanticExtractor.extractKeywords(
        text,
        maxKeywords: 10,
        ngramRange: (1, 3),
        diversityWeight: 0.3,
      );

      setState(() {
        _results[index] = _ChunkResult(
          ruleKeywords: ruleKeywords,
          semanticKeywords: semanticKeywords,
        );
        _processingChunkIndex = null;
      });
    } catch (e, st) {
      AppLogger.error('Semantic extraction failed for chunk $index', e, st);
      setState(() {
        _results[index] = _ChunkResult(
          ruleKeywords: [],
          semanticKeywords: [],
          error: e.toString(),
        );
        _processingChunkIndex = null;
      });
    }
  }

  Future<void> _processAllChunks() async {
    for (var i = 0; i < _chunks.length; i++) {
      if (!_results.containsKey(i)) {
        await _processChunk(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semantic Keyword Test'),
        actions: [
          if (_chunks.isNotEmpty)
            TextButton.icon(
              onPressed: _processingChunkIndex != null ? null : _processAllChunks,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Process All'),
            ),
        ],
      ),
      body: _buildBody(context, theme, colorScheme),
    );
  }

  Widget _buildBody(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Error: $_error'),
          ],
        ),
      );
    }

    if (_chunks.isEmpty) {
      return const Center(child: Text('No chunks found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chunks.length,
      itemBuilder: (context, index) =>
          _buildChunkCard(context, index, theme, colorScheme),
    );
  }

  Widget _buildChunkCard(
    BuildContext context,
    int index,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final chunk = _chunks[index];
    final result = _results[index];
    final isProcessing = _processingChunkIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Chunk ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${chunk.content.length} chars',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (result == null && !isProcessing)
                  FilledButton.tonal(
                    onPressed: () => _processChunk(index),
                    child: const Text('Extract'),
                  )
                else if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.check_circle, color: colorScheme.primary),
              ],
            ),

            const SizedBox(height: 12),

            // Sample text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chunk.content.length > 400
                    ? '${chunk.content.substring(0, 400)}...'
                    : chunk.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Results
            if (result != null) ...[
              const SizedBox(height: 16),

              if (result.error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Error: ${result.error}',
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                )
              else ...[
                // Rule-based keywords
                _buildKeywordSection(
                  context,
                  title: 'Rule-based (frequency + boost)',
                  icon: Icons.analytics_outlined,
                  keywords: result.ruleKeywords,
                  chipColor: colorScheme.tertiaryContainer,
                  textColor: colorScheme.onTertiaryContainer,
                ),

                const SizedBox(height: 12),

                // Semantic keywords
                _buildSemanticKeywordSection(
                  context,
                  title: 'Semantic (embedding similarity)',
                  icon: Icons.psychology_outlined,
                  keywords: result.semanticKeywords,
                  chipColor: colorScheme.secondaryContainer,
                  textColor: colorScheme.onSecondaryContainer,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> keywords,
    required Color chipColor,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: keywords
              .map((k) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      k,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSemanticKeywordSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<SemanticKeyword> keywords,
    required Color chipColor,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: keywords
              .map((k) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${k.keyword} (${(k.score * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _ChunkResult {
  final List<String> ruleKeywords;
  final List<SemanticKeyword> semanticKeywords;
  final String? error;

  _ChunkResult({
    required this.ruleKeywords,
    required this.semanticKeywords,
    this.error,
  });
}
