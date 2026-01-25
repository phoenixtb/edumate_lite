import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../config/service_locator.dart';
import '../../../stores/app_store.dart';
import '../../../stores/material_store.dart';
import '../../../domain/services/vision_service.dart';
import '../../widgets/material/processing_progress_card.dart';
import '../../widgets/common/image_picker_button.dart';
import '../../widgets/common/ocr_result_sheet.dart';
import '../shell/app_shell.dart';
import '../chat/chat_screen.dart';
import '../worksheet/worksheet_screen.dart';
import '../knowledge/knowledge_graph_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appStore = getIt<AppStore>();
    final materialStore = getIt<MaterialStore>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'EduMate',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [colorScheme.primary.withOpacity(0.8), colorScheme.secondary]
                        : [colorScheme.primary, colorScheme.tertiary],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -30,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Welcome Card
          SliverToBoxAdapter(
            child: Observer(
              builder: (_) => Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            materialStore.materials.isEmpty
                                ? 'Upload your first study material'
                                : '${materialStore.completedMaterials.length} materials ready',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Processing Progress (if any)
          SliverToBoxAdapter(
            child: Observer(
              builder: (_) {
                if (!materialStore.hasProcessingJobs) {
                  return const SizedBox.shrink();
                }
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ProcessingProgressCard(),
                );
              },
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: Observer(
              builder: (_) => Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.menu_book,
                        value: '${materialStore.completedMaterials.length}',
                        label: 'Materials',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.auto_stories,
                        value: '${_totalChunks(materialStore)}',
                        label: 'Chunks',
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.psychology,
                        value: appStore.isAppReady ? 'Ready' : '...',
                        label: 'AI Status',
                        color: appStore.isAppReady ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),

          // Quick Actions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ask Question',
                  subtitle: 'Chat with AI',
                  color: colorScheme.primary,
                  onTap: () => _openChat(context),
                ),
                _ActionCard(
                  icon: Icons.upload_file_outlined,
                  title: 'Add Material',
                  subtitle: 'PDF or Image',
                  color: colorScheme.secondary,
                  onTap: () => _goToTab(context, 3), // Library is now index 3
                ),
                _ActionCard(
                  icon: Icons.assignment_outlined,
                  title: 'Worksheet',
                  subtitle: 'Generate practice',
                  color: colorScheme.tertiary,
                  onTap: () => _openWorksheet(context),
                ),
                _ActionCard(
                  icon: Icons.hub_outlined,
                  title: 'Knowledge Graph',
                  subtitle: 'Explore concepts',
                  color: Colors.deepPurple,
                  onTap: () => _openKnowledgeGraph(context),
                ),
              ]),
            ),
          ),

          // Recent Materials
          SliverToBoxAdapter(
            child: Observer(
              builder: (_) {
                final recent = materialStore.completedMaterials.take(3).toList();
                if (recent.isEmpty) return const SizedBox(height: 100);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Materials',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () => _goToTab(context, 3),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: recent.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final material = recent[index];
                          return Container(
                            width: 200,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  material.sourceType == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.image,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  material.title,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _totalChunks(MaterialStore store) {
    return store.completedMaterials.fold(0, (sum, m) => sum + m.chunkCount);
  }

  void _goToTab(BuildContext context, int index) {
    final controller = AppShellController.of(context);
    controller?.switchTab(index);
  }

  void _openChat(BuildContext context) {
    final controller = AppShellController.of(context);
    controller?.openChat();
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openWorksheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WorksheetScreen()),
    );
  }

  void _openKnowledgeGraph(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KnowledgeGraphScreen()),
    );
  }

  void _openScanNotes(BuildContext context) {
    // Use ImagePickerButton's functionality inline
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Scan Handwritten Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo or select an image to extract text',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              ImagePickerButton(
                onImagePicked: (bytes, name) {
                  Navigator.pop(ctx);
                  _processScannedImage(context, bytes);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Select Image',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _processScannedImage(BuildContext context, Uint8List imageBytes) async {
    // Show loading sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const OCRResultSheet(
        extractedText: '',
        isLoading: true,
      ),
    );

    // Extract text using VisionService
    final extractedText = await VisionService.instance.extractText(imageBytes);

    // Close loading sheet and show result
    if (context.mounted) {
      Navigator.pop(context);
      
      OCRResultSheet.show(
        context,
        extractedText: extractedText,
        onSave: (title, content) {
          // Add scanned text as material
          _saveScannedMaterial(context, title, content);
        },
        onStartChat: (text) {
          // Navigate to chat with the extracted text as context
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ChatScreen(),
            ),
          );
        },
      );
    }
  }

  void _saveScannedMaterial(BuildContext context, String title, String content) {
    final materialStore = getIt<MaterialStore>();
    
    // Add text content as material (uses the text input adapter flow)
    materialStore.addTextMaterial(
      title: title,
      content: content,
      sourceType: 'text', // Uses TextInputAdapter
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Saved "$title" to materials')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _goToTab(context, 3), // Go to Library
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

