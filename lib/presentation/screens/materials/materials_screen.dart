import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import '../../../config/service_locator.dart';
import '../../../stores/material_store.dart';
import '../../widgets/material/material_card.dart';
import '../../widgets/material/processing_jobs_list.dart';
import 'add_material_dialog.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final materialStore = getIt<MaterialStore>();
  late final ReactionDisposer _scannedPdfDisposer;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _setupScannedPdfReaction();
  }

  @override
  void dispose() {
    _scannedPdfDisposer();
    super.dispose();
  }

  void _setupScannedPdfReaction() {
    _scannedPdfDisposer = reaction(
      (_) => materialStore.pendingScannedPdfInput,
      (input) {
        if (input != null && mounted) {
          _showScannedPdfDialog();
        }
      },
    );
  }

  void _showScannedPdfDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.document_scanner, size: 48, color: Colors.orange),
        title: const Text('Scanned PDF Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              materialStore.pendingScannedPdfMessage ??
                  'This PDF appears to be scanned or image-based.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to reprocess with AI Vision for better text extraction?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Vision is slower but handles scanned documents better.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              materialStore.cancelScannedPdfRetry();
            },
            child: const Text('Keep as-is'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              materialStore.retryWithVisionMode();
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Use AI Vision'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMaterials() async {
    await materialStore.loadMaterials();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Materials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMaterials,
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (materialStore.isLoading && materialStore.materials.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (materialStore.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load materials',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      materialStore.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () {
                            materialStore.error = null;
                            _loadMaterials();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          if (materialStore.materials.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadMaterials,
            child: CustomScrollView(
              slivers: [
                // Processing jobs at the top
                SliverToBoxAdapter(
                  child: const ProcessingJobsList(),
                ),
                // Materials list
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final material = materialStore.materials[index];
                        return MaterialCard(
                          material: material,
                          onDelete: () => _confirmDelete(material.id),
                          onRetry: material.status == 'failed'
                              ? () => materialStore.reprocessMaterial(material.id)
                              : null,
                          onEdit: (title, subject, grade) {
                            materialStore.updateMaterial(
                              materialId: material.id,
                              title: title,
                              subject: subject,
                              gradeLevel: grade,
                            );
                          },
                        );
                      },
                      childCount: materialStore.materials.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'chat_fab',
            onPressed: () => Navigator.pop(context),
            child: const Icon(Icons.chat),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_fab',
            onPressed: _showAddMaterialDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Material'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No materials yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add PDF files, images, or capture with camera',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddMaterialDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Material'),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddMaterialDialog(),
    );
  }

  Future<void> _confirmDelete(int materialId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: const Text(
          'This will delete the material and all its chunks. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await materialStore.deleteMaterial(materialId);
    }
  }
}
