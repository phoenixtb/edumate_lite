import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/entities/material.dart' as app;
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/chunk.dart';
import '../../../domain/entities/ai_task.dart';
import '../../../domain/services/llm_concept_extractor.dart';
import '../../../domain/services/inference_router.dart';
import 'semantic_keyword_test_screen.dart';
import '../../../stores/material_store.dart';
import '../../../stores/concept_store.dart';
import '../../../stores/task_queue_store.dart';
import '../../../infrastructure/database/objectbox_vector_store.dart';
import '../../widgets/concept/concept_chip.dart';
import '../../widgets/concept/concept_detail_sheet.dart';
import '../../widgets/concept/related_material_card.dart';

/// Full detail screen for a material with Overview, Concepts, and Related tabs
class MaterialDetailScreen extends StatefulWidget {
  final app.Material material;

  const MaterialDetailScreen({super.key, required this.material});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final materialStore = GetIt.I<MaterialStore>();
  final conceptStore = GetIt.I<ConceptStore>();
  final vectorStore = GetIt.I<ObjectBoxVectorStore>();

  List<Concept> _concepts = [];
  List<_RelatedMaterialData> _relatedMaterials = [];
  String _selectedType = 'all';
  bool _isExtracting = false;
  int _extractionProgress = 0;
  int _extractionTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    // Load concepts for this material
    _concepts = conceptStore.getConceptsForMaterial(widget.material.id);

    // Load related materials with shared concepts
    _loadRelatedMaterials();

    setState(() {});
  }

  Future<void> _extractConcepts() async {
    if (_isExtracting) return;

    // Get chunks for this material
    final chunks = await vectorStore.getByMaterial(widget.material.id);

    if (chunks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chunks found for this material')),
        );
      }
      return;
    }

    setState(() => _isExtracting = true);

    // Create the extraction task
    final taskQueue = GetIt.I<TaskQueueStore>();
    final materialId = widget.material.id;
    final materialTitle = widget.material.title;
    final subject = widget.material.subject;

    final task = AITask(
      type: TaskType.conceptExtraction,
      description:
          'Extracting from "${materialTitle.length > 30 ? '${materialTitle.substring(0, 30)}...' : materialTitle}"',
      priority: TaskPriority.low,
      materialId: materialId,
      materialTitle: materialTitle,
      execute: () => _createExtractionStream(chunks, materialId, subject),
      onComplete: (success, error) {
        if (mounted) {
          setState(() => _isExtracting = false);
          _loadData();
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Concepts extracted from ${chunks.length} chunks',
                ),
              ),
            );
          }
        }
      },
    );

    taskQueue.enqueue(task);

    // Show brief confirmation - FAB will show ongoing progress
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Extracting concepts from ${chunks.length} chunks...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Creates a stream that yields progress updates during extraction
  Stream<double> _createExtractionStream(
    List<Chunk> chunks,
    int materialId,
    String? subject,
  ) async* {
    AppLogger.info('🔄 [EXTRACTION] Starting for material=$materialId, chunks=${chunks.length}');
    final router = GetIt.I<InferenceRouter>();
    final llmExtractor = LLMConceptExtractor(router);

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      AppLogger.debug('🔄 [EXTRACTION] Processing chunk ${i + 1}/${chunks.length} (id=${chunk.id})');
      final concepts = await llmExtractor.extractAndStore(
        content: chunk.content,
        materialId: materialId,
        chunkId: chunk.id,
        subject: subject,
      );
      AppLogger.debug('🔄 [EXTRACTION] Chunk ${i + 1} yielded ${concepts.length} concepts');

      yield (i + 1) / chunks.length;
    }
    AppLogger.info('✅ [EXTRACTION] Completed for material=$materialId');
  }

  Future<void> _regenerateConcepts() async {
    // Confirm with user
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Concepts'),
        content: const Text(
          'This will clear existing concepts and extract new ones using AI. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Clear existing concepts for this material
    _clearConceptsForMaterial();

    // Extract new concepts
    await _extractConcepts();
  }

  void _clearConceptsForMaterial() {
    // Get concepts for this material and remove material reference
    final concepts = conceptStore.getConceptsForMaterial(widget.material.id);
    for (final concept in concepts) {
      final materialIds = concept.materialIds;
      materialIds.remove(widget.material.id);
      concept.materialIds = materialIds;

      // Also remove chunk IDs for this material's chunks
      // Note: We're not tracking which chunks belong to which material in concepts,
      // so we just leave chunkIds as is for now

      if (materialIds.isEmpty) {
        // Delete concept if no materials reference it
        conceptStore.deleteConcept(concept.id);
      } else {
        conceptStore.saveConcept(concept);
      }
    }
  }

  void _loadRelatedMaterials() {
    final myConceptIds = _concepts.map((c) => c.id).toSet();

    _relatedMaterials = [];

    for (final other in materialStore.materials) {
      if (other.id == widget.material.id || other.status != 'completed') {
        continue;
      }

      // Find shared concepts
      final otherConcepts = conceptStore.getConceptsForMaterial(other.id);
      final shared = otherConcepts
          .where((c) => myConceptIds.contains(c.id))
          .toList();

      if (shared.isNotEmpty) {
        // Calculate relevance score
        double score = 0.0;
        score += 0.5 * (shared.length / _concepts.length.clamp(1, 100));

        // Subject bonus
        if (widget.material.subject != null &&
            widget.material.subject == other.subject) {
          score += 0.3;
        }

        // Grade proximity
        if (widget.material.gradeLevel != null && other.gradeLevel != null) {
          final diff = (widget.material.gradeLevel! - other.gradeLevel!).abs();
          if (diff == 0) {
            score += 0.2;
          } else if (diff == 1) {
            score += 0.1;
          }
        }

        _relatedMaterials.add(
          _RelatedMaterialData(
            material: other,
            sharedConcepts: shared,
            score: score.clamp(0.0, 1.0),
          ),
        );
      }
    }

    // Sort by score
    _relatedMaterials.sort((a, b) => b.score.compareTo(a.score));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = widget.material;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _getSourceColor(
                material.sourceType,
              ).withValues(alpha: 0.2),
              child: Icon(
                _getSourceIcon(material.sourceType),
                color: _getSourceColor(material.sourceType),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (material.subject != null)
                    Text(
                      material.subject!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'test_keywords',
                child: Row(
                  children: [
                    Icon(Icons.science, size: 20, color: Colors.purple),
                    SizedBox(width: 12),
                    Text('Test Semantic Keywords'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.info_outline, size: 20),
              text: 'Overview',
            ),
            Tab(
              icon: Badge(
                label: Text('${_concepts.length}'),
                isLabelVisible: _concepts.isNotEmpty,
                child: const Icon(Icons.lightbulb_outline, size: 20),
              ),
              text: 'Concepts',
            ),
            Tab(
              icon: Badge(
                label: Text('${_relatedMaterials.length}'),
                isLabelVisible: _relatedMaterials.isNotEmpty,
                child: const Icon(Icons.hub_outlined, size: 20),
              ),
              text: 'Related',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context),
          _buildConceptsTab(context),
          _buildRelatedTab(context),
        ],
      ),
    );
  }

  Color _getSourceColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.blue;
      case 'camera':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOverviewTab(BuildContext context) {
    final material = widget.material;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.layers_outlined,
                label: 'Chunks',
                value: '${material.chunkCount}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.lightbulb_outline,
                label: 'Concepts',
                value: '${_concepts.length}',
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.hub_outlined,
                label: 'Related',
                value: '${_relatedMaterials.length}',
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Details
        _buildSectionHeader(context, 'Details', Icons.info_outline),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  context,
                  'Source Type',
                  material.sourceType.toUpperCase(),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Subject',
                  material.subject ?? 'Not set',
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Grade Level',
                  material.gradeLevel != null
                      ? 'Grade ${material.gradeLevel}'
                      : 'Not set',
                ),
                const Divider(height: 24),
                _buildDetailRow(context, 'Status', material.status),
                if (material.processedAt != null) ...[
                  const Divider(height: 24),
                  _buildDetailRow(
                    context,
                    'Processed',
                    _formatDate(material.processedAt!),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Top concepts preview
        if (_concepts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Top Concepts', Icons.lightbulb_outline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _concepts
                .take(8)
                .map(
                  (c) => ConceptChip(
                    concept: c,
                    showFrequency: true,
                    onTap: () => ConceptDetailSheet.show(
                      context,
                      c,
                      onMaterialTap: _navigateToMaterial,
                    ),
                  ),
                )
                .toList(),
          ),
          if (_concepts.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: Text('View all ${_concepts.length} concepts'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildConceptsTab(BuildContext context) {
    final theme = Theme.of(context);

    if (_concepts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No concepts extracted',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This material was processed before concept extraction was enabled.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isExtracting && _extractionTotal > 0) ...[
                Text(
                  'Processing chunk $_extractionProgress of $_extractionTotal',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _extractionProgress / _extractionTotal,
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _isExtracting ? null : _extractConcepts,
                icon: _isExtracting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isExtracting ? 'Extracting...' : 'Extract Concepts Now',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get unique types
    final types = {'all', ..._concepts.map((c) => c.type)}.toList();
    final typeCounts = <String, int>{};
    for (final c in _concepts) {
      typeCounts[c.type] = (typeCounts[c.type] ?? 0) + 1;
    }
    typeCounts['all'] = _concepts.length;

    // Filter concepts
    final filtered = _selectedType == 'all'
        ? _concepts
        : _concepts.where((c) => c.type == _selectedType).toList();

    return Column(
      children: [
        // Type filters + regenerate button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: types
                        .map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ConceptTypeFilter(
                              type: type,
                              selected: _selectedType == type,
                              count: typeCounts[type] ?? 0,
                              onTap: () => setState(() => _selectedType = type),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              // Regenerate button
              IconButton(
                onPressed: _isExtracting ? null : _regenerateConcepts,
                icon: _isExtracting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Regenerate concepts',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Concepts grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final concept = filtered[index];
              return ConceptChip(
                concept: concept,
                showFrequency: true,
                onTap: () => ConceptDetailSheet.show(
                  context,
                  concept,
                  onMaterialTap: _navigateToMaterial,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedTab(BuildContext context) {
    final theme = Theme.of(context);

    if (_relatedMaterials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No related materials',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Related materials share concepts with this one',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _relatedMaterials.length,
      itemBuilder: (context, index) {
        final data = _relatedMaterials[index];
        return RelatedMaterialCard(
          material: data.material,
          sharedConcepts: data.sharedConcepts,
          relevanceScore: data.score,
          onTap: () => _navigateToMaterial(data.material),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  IconData _getSourceIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'camera':
        return Icons.camera_alt;
      default:
        return Icons.description;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _showEditDialog();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
      case 'test_keywords':
        _testSemanticKeywords();
        break;
    }
  }

  /// Navigate to semantic keyword test screen
  void _testSemanticKeywords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SemanticKeywordTestScreen(material: widget.material),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final titleController = TextEditingController(text: widget.material.title);
    String? selectedSubject = widget.material.subject;
    int? selectedGrade = widget.material.gradeLevel;

    const subjects = ['math', 'science', 'history', 'english', 'other'];
    const grades = [5, 6, 7, 8, 9, 10, 11, 12];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...subjects.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => selectedSubject = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...grades.map(
                      (g) =>
                          DropdownMenuItem(value: g, child: Text('Grade $g')),
                    ),
                  ],
                  onChanged: (v) => setState(() => selectedGrade = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await materialStore.updateMaterial(
        materialId: widget.material.id,
        title: titleController.text.trim(),
        subject: selectedSubject,
        gradeLevel: selectedGrade,
      );
      setState(() {});
    }

    titleController.dispose();
  }

  Future<void> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material'),
        content: const Text(
          'Are you sure you want to delete this material? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await materialStore.deleteMaterial(widget.material.id);
      Navigator.pop(context);
    }
  }

  void _navigateToMaterial(app.Material material) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialDetailScreen(material: material),
      ),
    );
  }
}

class _RelatedMaterialData {
  final app.Material material;
  final List<Concept> sharedConcepts;
  final double score;

  _RelatedMaterialData({
    required this.material,
    required this.sharedConcepts,
    required this.score,
  });
}
