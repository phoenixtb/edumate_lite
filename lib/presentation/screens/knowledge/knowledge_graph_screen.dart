import 'package:flutter/material.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';
import 'package:get_it/get_it.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/material.dart' as app;
import '../../../stores/concept_store.dart';
import '../../../stores/material_store.dart';
import '../../widgets/concept/concept_detail_sheet.dart';
import '../materials/material_detail_screen.dart';

/// Interactive knowledge graph visualization
class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  final conceptStore = GetIt.I<ConceptStore>();
  final materialStore = GetIt.I<MaterialStore>();

  Graph? _graph;
  String _selectedType = 'all';
  Concept? _selectedConcept;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    setState(() => _isLoading = true);

    // Load all concepts
    conceptStore.loadConcepts();

    // Exclude keyword-based concepts (only show LLM-extracted)
    final concepts = conceptStore.concepts
        .where((c) => c.type != 'keyword')
        .toList();
    if (concepts.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Filter by type if selected
    final filtered = _selectedType == 'all'
        ? concepts.toList()
        : concepts.where((c) => c.type == _selectedType).toList();

    // Create graph data
    final data = <String, dynamic>{
      'nodes': <Map<String, dynamic>>[],
      'edges': <Map<String, dynamic>>[],
    };

    // Create nodes
    for (final concept in filtered) {
      data['nodes']!.add({
        'id': concept.id.toString(),
        'tag': concept.name,
        'data': concept,
      });
    }

    // Create edges from relationships
    final nodeIds = filtered.map((c) => c.id).toSet();
    for (final concept in filtered) {
      for (final relatedId in concept.relatedConceptIds) {
        if (nodeIds.contains(relatedId) && concept.id < relatedId) {
          // Only add edge once (smaller ID to larger ID)
          data['edges']!.add({
            'srcId': concept.id.toString(),
            'dstId': relatedId.toString(),
          });
        }
      }

      // Also link concepts that share materials
      for (final other in filtered) {
        if (other.id <= concept.id) continue;
        final sharedMaterials = concept.materialIds
            .where((m) => other.materialIds.contains(m))
            .length;
        if (sharedMaterials >= 2) {
          // Only link if they share 2+ materials
          final edgeExists = data['edges']!.any((e) =>
              (e['srcId'] == concept.id.toString() &&
                  e['dstId'] == other.id.toString()) ||
              (e['srcId'] == other.id.toString() &&
                  e['dstId'] == concept.id.toString()));
          if (!edgeExists) {
            data['edges']!.add({
              'srcId': concept.id.toString(),
              'dstId': other.id.toString(),
            });
          }
        }
      }
    }

    // Build the graph
    _graph = Graph()..data = data;

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Exclude keyword-based concepts
    final concepts = conceptStore.concepts
        .where((c) => c.type != 'keyword')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Graph'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearch,
            tooltip: 'Search concepts',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _buildGraph,
            tooltip: 'Rebuild graph',
          ),
        ],
      ),
      body: Column(
        children: [
          // Type filter chips - only show when concepts exist
          if (concepts.isNotEmpty) _buildFilterChips(context),

          // Graph or empty state
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : concepts.isEmpty
                    ? _buildEmptyState(context)
                    : _graph != null && _graph!.vertexes.isNotEmpty
                        ? _buildGraphView(context)
                        : _buildEmptyState(context),
          ),

          // Selected concept info
          if (_selectedConcept != null) _buildSelectedInfo(context),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    // Exclude keyword type from filter chips
    final llmConcepts = conceptStore.concepts.where((c) => c.type != 'keyword');
    final types = {'all', ...llmConcepts.map((c) => c.type)}.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: types.map((type) {
          final count = type == 'all'
              ? llmConcepts.length
              : llmConcepts.where((c) => c.type == type).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getTypeIcon(type),
                    size: 16,
                    color: _selectedType == type
                        ? Theme.of(context).colorScheme.onPrimary
                        : _getTypeColor(type),
                  ),
                  const SizedBox(width: 6),
                  Text(_getTypeLabel(type)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _selectedType == type
                          ? Colors.white.withValues(alpha: 0.2)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _selectedType == type
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              selected: _selectedType == type,
              onSelected: (_) {
                setState(() => _selectedType = type);
                _buildGraph();
              },
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGraphView(BuildContext context) {
    if (_graph == null || _graph!.vertexes.isEmpty) {
      return _buildEmptyState(context);
    }

    // Build tag color map from concept types
    final tagColorMap = <String, Color>{
      'term': Colors.blue,
      'person': Colors.teal,
      'formula': Colors.purple,
      'theorem': Colors.indigo,
      'event': Colors.orange,
      'place': Colors.green,
      'definition': Colors.cyan,
      'concept': Colors.amber,
    };

    final options = Options()
      ..enableHit = true
      ..panelDelay = const Duration(milliseconds: 500)
      ..showText = true
      ..textGetter = (vertex) {
        final concept = vertex.data as Concept?;
        return concept?.name ?? vertex.id.toString();
      }
      ..graphStyle = (GraphStyle()
        ..tagColor = tagColorMap
        ..tagColorByIndex = [
          Colors.blue,
          Colors.teal,
          Colors.purple,
          Colors.orange,
          Colors.green,
          Colors.cyan,
          Colors.amber,
          Colors.indigo,
        ])
      ..onVertexTapUp = (vertex, _) {
        final concept = vertex.data as Concept?;
        if (concept != null) {
          setState(() => _selectedConcept = concept);
        }
      }
      ..vertexPanelBuilder = (Vertex hoverVertex) {
        final concept = hoverVertex.data as Concept?;
        if (concept == null) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _getTypeColor(concept.type).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getTypeColor(concept.type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(concept.type),
                      size: 16,
                      color: _getTypeColor(concept.type),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          concept.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getTypeLabel(concept.type),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _getTypeColor(concept.type),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniStat(context, Icons.repeat, '${concept.frequency}'),
                  const SizedBox(width: 12),
                  _buildMiniStat(context, Icons.library_books_outlined, '${concept.materialIds.length}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to select • Double-tap for details',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      };

    return FlutterGraphWidget(
      data: _graph!,
      algorithm: RandomAlgorithm(
        decorators: [
          CoulombDecorator(),
          HookeDecorator(),
          ForceMotionDecorator(),
          CoulombCenterDecorator(),
        ],
      ),
      convertor: MapConvertor(),
      options: options,
    );
  }

  Widget _buildMiniStat(BuildContext context, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No concepts yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload materials to start building\nyour knowledge graph',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Materials'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInfo(BuildContext context) {
    final theme = Theme.of(context);
    final concept = _selectedConcept!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getTypeColor(concept.type).withValues(alpha: 0.2),
              child: Icon(
                _getTypeIcon(concept.type),
                color: _getTypeColor(concept.type),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    concept.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${concept.frequency} occurrences • ${concept.materialIds.length} materials',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => ConceptDetailSheet.show(
                context,
                concept,
                onMaterialTap: _navigateToMaterial,
              ),
              tooltip: 'View details',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedConcept = null),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: _ConceptSearchDelegate(
        concepts: conceptStore.concepts.toList(),
        onSelect: (concept) {
          setState(() => _selectedConcept = concept);
        },
        onDetailsTap: (concept) {
          ConceptDetailSheet.show(
            context,
            concept,
            onMaterialTap: _navigateToMaterial,
          );
        },
      ),
    );
  }

  void _navigateToMaterial(app.Material material) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialDetailScreen(material: material),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'all':
        return Icons.select_all;
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
      case 'all':
        return 'All';
      case 'person':
        return 'People';
      case 'formula':
        return 'Formulas';
      case 'theorem':
        return 'Theorems';
      case 'event':
        return 'Events';
      case 'place':
        return 'Places';
      case 'definition':
        return 'Definitions';
      case 'concept':
        return 'Concepts';
      default:
        return 'Terms';
    }
  }
}

/// Search delegate for concepts
class _ConceptSearchDelegate extends SearchDelegate<Concept?> {
  final List<Concept> concepts;
  final Function(Concept) onSelect;
  final Function(Concept) onDetailsTap;

  _ConceptSearchDelegate({
    required this.concepts,
    required this.onSelect,
    required this.onDetailsTap,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final filtered = query.isEmpty
        ? concepts
        : concepts
            .where((c) =>
                c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.normalizedName.contains(query.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No concepts found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final concept = filtered[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getTypeColor(concept.type).withValues(alpha: 0.2),
            child: Icon(
              _getTypeIcon(concept.type),
              color: _getTypeColor(concept.type),
              size: 20,
            ),
          ),
          title: Text(concept.name),
          subtitle: Text(
            '${concept.type} • ${concept.frequency} occurrences',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              close(context, null);
              onDetailsTap(concept);
            },
          ),
          onTap: () {
            close(context, concept);
            onSelect(concept);
          },
        );
      },
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
}
