import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../config/service_locator.dart';
import '../../../stores/app_store.dart';
import '../../../stores/material_store.dart';
import '../../../stores/model_download_store.dart';
import '../../../domain/services/model_download_service.dart';
import '../../../domain/services/inference_router.dart';
import '../../../infrastructure/ai/model_manager.dart';
import '../dev_tools/dev_tools_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _checkDeepseekStatus();
  }

  Future<void> _checkDeepseekStatus() async {
    final downloadService = getIt<ModelDownloadService>();
    final appStore = getIt<AppStore>();
    final downloadStore = getIt<ModelDownloadStore>();
    
    // Check if DeepSeek is already downloaded
    final hasDeepseek = await downloadService.hasPhi4Model();
    if (hasDeepseek) {
      appStore.setPhi4ModelReady(true);
      // Also update download store status to reflect completed state
      downloadStore.setPhi4Status(ModelDownloadStatus.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appStore = getIt<AppStore>();
    final materialStore = getIt<MaterialStore>();
    final downloadStore = getIt<ModelDownloadStore>();
    final downloadService = getIt<ModelDownloadService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          Card(
            child: Observer(
              builder: (_) => Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getThemeIcon(appStore.themeMode),
                        color: colorScheme.primary,
                      ),
                    ),
                    title: const Text('Theme'),
                    subtitle: Text(_getThemeLabel(appStore.themeMode)),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 18),
                        ),
                      ],
                      selected: {appStore.themeMode},
                      onSelectionChanged: (selection) {
                        appStore.setThemeMode(selection.first);
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Developer Section
          _SectionHeader(title: 'Developer'),
          Card(
            child: Observer(
              builder: (_) => Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.developer_mode,
                        color: colorScheme.tertiary,
                      ),
                    ),
                    title: const Text('Developer Mode'),
                    subtitle: const Text('Show debug info and tools'),
                    value: appStore.devModeEnabled,
                    onChanged: (value) => appStore.setDevModeEnabled(value),
                  ),
                  if (appStore.devModeEnabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.bug_report,
                          color: colorScheme.secondary,
                        ),
                      ),
                      title: const Text('Debug Console'),
                      subtitle: const Text('View chunks, embeddings & logs'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DevToolsScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Data Section
          _SectionHeader(title: 'Data'),
          Card(
            child: Column(
              children: [
                Observer(
                  builder: (_) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storage, color: Colors.blue),
                    ),
                    title: const Text('Materials'),
                    subtitle: Text(
                      '${materialStore.materials.length} materials, '
                      '${_totalChunks(materialStore)} chunks',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_sweep, color: Colors.red),
                  ),
                  title: const Text('Clear All Data'),
                  subtitle: const Text('Delete all materials and chats'),
                  onTap: () => _confirmClearData(context, materialStore),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // AI Models Section
          _SectionHeader(title: 'AI Models'),
          Card(
            child: Observer(
              builder: (_) => Column(
                children: [
                  // Active Model Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Active for text: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          appStore.shouldUsePhi4 ? 'DeepSeek R1' : 'Gemma 3n E2B',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Gemma 3n E2B (bundled, vision)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        appStore.isInferenceModelReady
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        color: appStore.isInferenceModelReady
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    title: const Text('Gemma 3n E2B'),
                    subtitle: Text(
                      appStore.isInferenceModelReady
                          ? 'Vision & text • Bundled'
                          : 'Loading...',
                    ),
                    trailing: !appStore.shouldUsePhi4 && appStore.isInferenceModelReady
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const Divider(height: 1),
                  // Embedding Model
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        appStore.isEmbeddingModelReady
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        color: appStore.isEmbeddingModelReady
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    title: const Text('EmbeddingGemma 300M'),
                    subtitle: Text(
                      appStore.isEmbeddingModelReady
                          ? 'Semantic search • Bundled'
                          : 'Loading...',
                    ),
                  ),
                  const Divider(height: 1),
                  // DeepSeek R1 (optional download)
                  _buildPhi4Tile(
                    context,
                    appStore,
                    downloadStore,
                    downloadService,
                    colorScheme,
                  ),
                ],
              ),
            ),
          ),
          
          // Model Preference Section (always show, but toggle only works if DeepSeek is ready)
          Observer(
            builder: (_) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Text Model Preference'),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.blue),
                          ),
                          title: const Text('Use DeepSeek for text'),
                          subtitle: Text(
                            appStore.isPhi4ModelReady
                                ? 'Better quality answers'
                                : 'Download DeepSeek first',
                          ),
                          value: appStore.preferPhi4ForText && appStore.isPhi4ModelReady,
                          onChanged: appStore.isPhi4ModelReady
                              ? (value) async {
                                  if (value) {
                                    await _switchToDeepSeek(context, appStore);
                                  } else {
                                    await _switchToGemma(context, appStore);
                                  }
                                }
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            !appStore.isPhi4ModelReady
                                ? 'Download DeepSeek R1 from above to enable this option.'
                                : appStore.preferPhi4ForText
                                    ? 'DeepSeek will be used for text queries. Gemma 3n for images.'
                                    : 'Gemma 3n will be used for all queries.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // About Section
          _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.info_outline, color: colorScheme.primary),
                  ),
                  title: const Text('EduMate Lite'),
                  subtitle: const Text('Version 1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.memory, color: Colors.orange),
                  ),
                  title: const Text('Powered by'),
                  subtitle: const Text('On-device AI models'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  int _totalChunks(MaterialStore store) {
    return store.completedMaterials.fold(0, (sum, m) => sum + m.chunkCount);
  }

  Widget _buildPhi4Tile(
    BuildContext context,
    AppStore appStore,
    ModelDownloadStore downloadStore,
    ModelDownloadService downloadService,
    ColorScheme colorScheme,
  ) {
    final isPhi4Ready = appStore.isPhi4ModelReady;
    final isDownloading = downloadStore.isPhi4Downloading;
    final hasFailed = downloadStore.phi4Status == ModelDownloadStatus.failed;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPhi4Ready && appStore.shouldUsePhi4
              ? Colors.green.withOpacity(0.15)
              : Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: isPhi4Ready && appStore.shouldUsePhi4
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Icon(
          isPhi4Ready
              ? Icons.check_circle
              : isDownloading
                  ? Icons.downloading
                  : Icons.cloud_download_outlined,
          color: isPhi4Ready
              ? Colors.green
              : isDownloading
                  ? Colors.blue
                  : Colors.amber,
        ),
      ),
      title: const Text('DeepSeek R1'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Enhanced',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              if (isPhi4Ready && appStore.shouldUsePhi4) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          if (isDownloading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: downloadStore.phi4Progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 2),
                Text(
                  'Downloading... ${downloadStore.phi4ProgressText}',
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              ],
            )
          else
            Text(
              isPhi4Ready
                  ? 'Better text answers • Downloaded'
                  : hasFailed
                      ? 'Download failed'
                      : 'Better text answers • Optional',
              style: TextStyle(
                fontSize: 11,
                color: hasFailed ? Colors.red : colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: isPhi4Ready
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirmed = await _confirmDeletePhi4(context);
                  if (confirmed == true) {
                    await downloadService.deletePhi4Model();
                    appStore.setPhi4ModelReady(false);
                    final router = getIt<InferenceRouter>();
                    await router.refreshModelState();
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          : isDownloading
              ? null
              : IconButton.filled(
                  onPressed: () => _downloadPhi4(
                    context,
                    appStore,
                    downloadService,
                  ),
                  icon: const Icon(Icons.download, size: 20),
                  tooltip: 'Download DeepSeek R1',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    foregroundColor: Colors.amber.shade700,
                  ),
                ),
    );
  }

  Future<void> _downloadPhi4(
    BuildContext context,
    AppStore appStore,
    ModelDownloadService downloadService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download DeepSeek R1?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will download ~2.5 GB of data.'),
            SizedBox(height: 8),
            Text(
              'DeepSeek provides better reasoning with "thinking mode" for text questions.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await downloadService.downloadPhi4Model();
      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (_) async {
          appStore.setPhi4ModelReady(true);
          
          if (!context.mounted) return;
          
          // Ask user if they want to switch to DeepSeek now
          final shouldSwitch = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('DeepSeek Ready!'),
              content: const Text(
                'DeepSeek R1 downloaded successfully.\n\n'
                'Would you like to switch to DeepSeek for text queries now? '
                'This will take about 30-60 seconds to load.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Switch Now'),
                ),
              ],
            ),
          );
          
          if (shouldSwitch == true && context.mounted) {
            await _switchToDeepSeek(context, appStore);
          }
        },
      );
    }
  }
  
  Future<void> _switchToDeepSeek(BuildContext context, AppStore appStore) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Loading DeepSeek R1...\nThis may take up to a minute.')),
          ],
        ),
      ),
    );
    
    try {
      appStore.setPreferPhi4ForText(true);
      final success = await ModelManager.instance.switchToDeepseek();
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Switched to DeepSeek R1 for text queries' 
              : 'Failed to switch model'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _switchToGemma(BuildContext context, AppStore appStore) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Loading Gemma 3n...\nThis may take up to a minute.')),
          ],
        ),
      ),
    );
    
    try {
      appStore.setPreferPhi4ForText(false);
      ModelManager.instance.clearReturnFlag();
      final success = await ModelManager.instance.switchToGemma();
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Switched to Gemma 3n for all queries' 
              : 'Failed to switch model'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _confirmDeletePhi4(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete DeepSeek R1?'),
        content: const Text(
          'This will free up ~2.5 GB of storage. You can re-download it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context, MaterialStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all materials, chunks, and conversations. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              // TODO: Implement clear all data
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

