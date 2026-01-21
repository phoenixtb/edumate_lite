import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;
import '../../../config/service_locator.dart';
import '../../../stores/worksheet_store.dart';
import '../../../domain/entities/worksheet.dart';

/// Screen to preview generated worksheet and export to PDF
class WorksheetPreviewScreen extends StatefulWidget {
  const WorksheetPreviewScreen({super.key});

  @override
  State<WorksheetPreviewScreen> createState() => _WorksheetPreviewScreenState();
}

class _WorksheetPreviewScreenState extends State<WorksheetPreviewScreen> {
  final worksheetStore = getIt<WorksheetStore>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Preview'),
        actions: [
          Observer(
            builder: (_) => IconButton(
              icon: worksheetStore.isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: worksheetStore.isExporting ? null : _exportPdf,
            ),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          final worksheet = worksheetStore.currentWorksheet;

          if (worksheet == null) {
            return const Center(
              child: Text('No worksheet generated'),
            );
          }

          return Column(
            children: [
              // Header card
              _buildHeaderCard(worksheet),

              // Problem list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: worksheet.problems.length,
                  itemBuilder: (context, index) {
                    return _buildProblemCard(
                      worksheet.problems[index],
                      index + 1,
                    );
                  },
                ),
              ),

              // Bottom action bar
              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(Worksheet worksheet) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              worksheet.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildChip(
                  Icons.school,
                  'Grade ${worksheet.gradeLevel}',
                ),
                _buildChip(
                  Icons.category,
                  _capitalize(worksheet.subject),
                ),
                _buildChip(
                  Icons.speed,
                  _capitalize(worksheet.difficulty),
                ),
                _buildChip(
                  Icons.quiz,
                  '${worksheet.problemCount} problems',
                ),
              ],
            ),
            if (worksheet.topic != null) ...[
              const SizedBox(height: 8),
              Text(
                'Topic: ${worksheet.topic}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildProblemCard(Problem problem, int number) {
    final theme = Theme.of(context);
    final showAnswer = worksheetStore.includeAnswerKey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getDifficultyColor(problem.difficulty),
          foregroundColor: Colors.white,
          child: Text('$number'),
        ),
        title: Text(
          problem.question,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _capitalize(problem.difficulty),
          style: TextStyle(
            color: _getDifficultyColor(problem.difficulty),
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full question
                Text(
                  problem.question,
                  style: theme.textTheme.bodyLarge,
                ),

                if (showAnswer && problem.answer.isNotEmpty) ...[
                  const Divider(height: 24),

                  // Answer
                  Text(
                    'Answer:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    problem.answer,
                    style: theme.textTheme.bodyMedium,
                  ),

                  // Steps if available
                  if (problem.hasSteps && worksheetStore.includeSteps) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Solution Steps:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...problem.steps.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key + 1}. ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _regenerate,
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Observer(
                builder: (_) => FilledButton.icon(
                  onPressed: worksheetStore.isExporting ? null : _exportPdf,
                  icon: worksheetStore.isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share),
                  label: Text(worksheetStore.isExporting
                      ? 'Exporting...'
                      : 'Export & Share'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _regenerate() {
    worksheetStore.clearWorksheet();
    Navigator.pop(context);
  }

  Future<void> _exportPdf() async {
    final bytes = await worksheetStore.exportToPdf();

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(worksheetStore.error ?? 'Export failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Save to temp file and share
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _sanitizeFileName(
          worksheetStore.currentWorksheet?.title ?? 'worksheet');
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Practice Worksheet - ${worksheetStore.currentWorksheet?.title}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
