import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/material.dart' as app;
import '../../../stores/concept_store.dart';
import '../../../stores/material_store.dart';
import '../../../domain/services/inference_router.dart';
import 'concept_chip.dart';

/// Bottom sheet showing detailed concept information
class ConceptDetailSheet extends StatefulWidget {
  final Concept concept;
  final Function(app.Material)? onMaterialTap;

  const ConceptDetailSheet({
    super.key,
    required this.concept,
    this.onMaterialTap,
  });

  /// Show the concept detail sheet
  static Future<void> show(
    BuildContext context,
    Concept concept, {
    Function(app.Material)? onMaterialTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConceptDetailSheet(
        concept: concept,
        onMaterialTap: onMaterialTap,
      ),
    );
  }

  @override
  State<ConceptDetailSheet> createState() => _ConceptDetailSheetState();
}

class _ConceptDetailSheetState extends State<ConceptDetailSheet> {
  final conceptStore = GetIt.I<ConceptStore>();
  final materialStore = GetIt.I<MaterialStore>();

  bool _isExplaining = false;
  String? _aiExplanation;
  List<Concept> _relatedConcepts = [];
  List<app.Material> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Load related concepts
    _relatedConcepts = conceptStore.getLinkedConcepts(widget.concept.id);
    if (_relatedConcepts.isEmpty) {
      _relatedConcepts = conceptStore.getRelatedConcepts(widget.concept.id, limit: 8);
    }

    // Load materials
    final materialIds = widget.concept.materialIds;
    _materials = materialStore.materials
        .where((m) => materialIds.contains(m.id))
        .toList();

    setState(() {});
  }

  Future<void> _explainWithAI() async {
    if (_isExplaining) return;

    setState(() => _isExplaining = true);

    try {
      final router = GetIt.I<InferenceRouter>();
      final systemPrompt = 'You are a helpful educational assistant. Explain terms simply and concisely.';
      final query = 'Explain the term "${widget.concept.name}" in simple, educational terms. Keep your explanation concise (2-3 sentences) and suitable for a student. If it\'s a technical term, include a brief example.';

      final buffer = StringBuffer();
      await for (final chunk in router.generate(
        systemPrompt: systemPrompt,
        context: '',
        query: query,
      )) {
        buffer.write(chunk);
      }

      setState(() {
        _aiExplanation = buffer.toString().trim();
        _isExplaining = false;
      });
    } catch (e) {
      setState(() {
        _aiExplanation = 'Could not generate explanation: $e';
        _isExplaining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final concept = widget.concept;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Header
                  _buildHeader(context, concept),
                  const SizedBox(height: 20),

                  // Definition section
                  _buildDefinitionSection(context, concept),
                  const SizedBox(height: 24),

                  // Stats
                  _buildStatsRow(context, concept),
                  const SizedBox(height: 24),

                  // Materials section
                  if (_materials.isNotEmpty) ...[
                    _buildMaterialsSection(context),
                    const SizedBox(height: 24),
                  ],

                  // Related concepts
                  if (_relatedConcepts.isNotEmpty) ...[
                    _buildRelatedSection(context),
                    const SizedBox(height: 24),
                  ],

                  // AI Explain button
                  _buildAISection(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Concept concept) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _getTypeColor(concept.type).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _getTypeIcon(concept.type),
            size: 28,
            color: _getTypeColor(concept.type),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concept.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTypeColor(concept.type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getTypeLabel(concept.type),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _getTypeColor(concept.type),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefinitionSection(BuildContext context, Concept concept) {
    final theme = Theme.of(context);

    if (concept.definition == null && _aiExplanation == null) {
      return const SizedBox.shrink();
    }

    final text = _aiExplanation ?? concept.definition;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Definition',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, Concept concept) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.repeat,
            label: 'Frequency',
            value: '${concept.frequency}',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.library_books_outlined,
            label: 'Materials',
            value: '${concept.materialIds.length}',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.hub_outlined,
            label: 'Related',
            value: '${_relatedConcepts.length}',
            color: Colors.purple,
          ),
        ),
      ],
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Appears in Materials',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_materials.map((material) => _buildMaterialTile(context, material))),
      ],
    );
  }

  Widget _buildMaterialTile(BuildContext context, app.Material material) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSourceColor(material.sourceType).withValues(alpha: 0.2),
          child: Icon(
            _getSourceIcon(material.sourceType),
            color: _getSourceColor(material.sourceType),
            size: 20,
          ),
        ),
        title: Text(
          material.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: material.subject != null
            ? Text(
                material.subject!,
                style: theme.textTheme.bodySmall,
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          widget.onMaterialTap?.call(material);
        },
      ),
    );
  }

  Widget _buildRelatedSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Related Concepts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _relatedConcepts.map((c) => ConceptChip(
            concept: c,
            onTap: () {
              Navigator.pop(context);
              ConceptDetailSheet.show(
                context,
                c,
                onMaterialTap: widget.onMaterialTap,
              );
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildAISection(BuildContext context) {
    final theme = Theme.of(context);

    if (_aiExplanation != null && !_isExplaining) {
      return const SizedBox.shrink(); // Already shown in definition
    }

    return FilledButton.icon(
      onPressed: _isExplaining ? null : _explainWithAI,
      icon: _isExplaining
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(_isExplaining ? 'Generating...' : 'Explain with AI'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return Icons.person_outline;
      case 'formula':
        return Icons.functions;
      case 'theorem':
        return Icons.auto_awesome;
      case 'event':
        return Icons.event;
      case 'place':
        return Icons.place_outlined;
      case 'definition':
        return Icons.menu_book_outlined;
      case 'concept':
        return Icons.lightbulb_outline;
      default:
        return Icons.label_outline;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return Colors.teal;
      case 'formula':
        return Colors.purple;
      case 'theorem':
        return Colors.indigo;
      case 'event':
        return Colors.orange;
      case 'place':
        return Colors.green;
      case 'definition':
        return Colors.cyan;
      case 'concept':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return 'Person';
      case 'formula':
        return 'Formula';
      case 'theorem':
        return 'Theorem';
      case 'event':
        return 'Event';
      case 'place':
        return 'Place';
      case 'definition':
        return 'Definition';
      case 'concept':
        return 'Concept';
      default:
        return 'Term';
    }
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
}
