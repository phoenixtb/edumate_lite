import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../config/service_locator.dart';
import '../../../stores/worksheet_store.dart';
import '../../../stores/material_store.dart';
import 'worksheet_preview_screen.dart';

/// Screen for configuring worksheet generation
class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key});

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  final worksheetStore = getIt<WorksheetStore>();
  final materialStore = getIt<MaterialStore>();
  final _topicController = TextEditingController();

  static const subjects = ['math', 'science', 'history', 'english', 'other'];
  static const difficulties = ['easy', 'medium', 'hard', 'mixed'];

  @override
  void initState() {
    super.initState();
    worksheetStore.reset();
    materialStore.loadMaterials();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Worksheet'),
      ),
      body: Observer(
        builder: (_) {
          if (worksheetStore.isGenerating) {
            return _buildGeneratingState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Generate practice problems from your materials',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Material Selection
                _buildSectionHeader('Select Materials', Icons.library_books),
                const SizedBox(height: 8),
                _buildMaterialSelector(),
                const SizedBox(height: 24),

                // Configuration
                _buildSectionHeader('Configuration', Icons.tune),
                const SizedBox(height: 12),

                // Grade Level
                _buildSliderOption(
                  label: 'Grade Level',
                  value: worksheetStore.gradeLevel.toDouble(),
                  min: 5,
                  max: 10,
                  divisions: 5,
                  labelBuilder: (v) => 'Grade ${v.toInt()}',
                  onChanged: (v) => worksheetStore.setGradeLevel(v.toInt()),
                ),
                const SizedBox(height: 16),

                // Problem Count
                _buildSliderOption(
                  label: 'Number of Problems',
                  value: worksheetStore.problemCount.toDouble(),
                  min: 5,
                  max: 20,
                  divisions: 15,
                  labelBuilder: (v) => '${v.toInt()} problems',
                  onChanged: (v) => worksheetStore.setProblemCount(v.toInt()),
                ),
                const SizedBox(height: 16),

                // Subject & Difficulty Row
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownOption(
                        label: 'Subject',
                        value: worksheetStore.subject,
                        items: subjects,
                        onChanged: (v) =>
                            worksheetStore.setSubject(v ?? 'math'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownOption(
                        label: 'Difficulty',
                        value: worksheetStore.difficulty,
                        items: difficulties,
                        onChanged: (v) =>
                            worksheetStore.setDifficulty(v ?? 'medium'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Topic (optional)
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: 'Topic (optional)',
                    hintText: 'e.g., Algebraic Equations',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: worksheetStore.setTopic,
                ),
                const SizedBox(height: 24),

                // Options
                _buildSectionHeader('Options', Icons.settings),
                const SizedBox(height: 8),

                _buildSwitchOption(
                  label: 'Include step-by-step solutions',
                  value: worksheetStore.includeSteps,
                  onChanged: worksheetStore.setIncludeSteps,
                ),
                _buildSwitchOption(
                  label: 'Include answer key',
                  value: worksheetStore.includeAnswerKey,
                  onChanged: worksheetStore.setIncludeAnswerKey,
                ),
                const SizedBox(height: 32),

                // Error
                if (worksheetStore.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            worksheetStore.error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: worksheetStore.clearError,
                        ),
                      ],
                    ),
                  ),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        worksheetStore.canGenerate ? _generateWorksheet : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Worksheet'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Generating Worksheet...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Observer(
              builder: (_) => Column(
                children: [
                  LinearProgressIndicator(
                    value: worksheetStore.generationProgress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    worksheetStore.generationMessage ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildMaterialSelector() {
    return Observer(
      builder: (_) {
        final materials = materialStore.materials
            .where((m) => m.status == 'completed')
            .toList();

        if (materials.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  const Text('No processed materials available'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Add Materials First'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: materials.map((material) {
              final isSelected =
                  worksheetStore.selectedMaterialIds.contains(material.id);
              return CheckboxListTile(
                title: Text(material.title),
                subtitle: Text(
                  '${material.subject ?? 'Unknown'} • ${material.chunkCount} chunks',
                ),
                value: isSelected,
                onChanged: (selected) {
                  if (selected == true) {
                    worksheetStore.addMaterial(material.id);
                  } else {
                    worksheetStore.removeMaterial(material.id);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSliderOption({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) labelBuilder,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              labelBuilder(value),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdownOption({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(_capitalize(item)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _generateWorksheet() async {
    await worksheetStore.generateWorksheet();

    if (worksheetStore.currentWorksheet != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WorksheetPreviewScreen(),
        ),
      );
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
