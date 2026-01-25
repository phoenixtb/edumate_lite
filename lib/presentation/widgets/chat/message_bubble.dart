import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/chunk.dart';
import '../../../infrastructure/database/objectbox_vector_store.dart';
import '../../../config/service_locator.dart';

class MessageBubble extends StatefulWidget {
  final Message? message;
  final String? streamingContent;
  final VoidCallback? onRegenerate;

  const MessageBubble({
    super.key,
    this.message,
    this.onRegenerate,
  }) : streamingContent = null;

  const MessageBubble.streaming({
    super.key,
    required String content,
  })  : streamingContent = content,
        message = null,
        onRegenerate = null;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _sourcesExpanded = false;
  List<Chunk>? _sourceChunks;
  bool _loadingSources = false;

  Message? get message => widget.message;
  String? get streamingContent => widget.streamingContent;
  VoidCallback? get onRegenerate => widget.onRegenerate;
  
  bool get isUser => message?.role == 'user';
  bool get isStreaming => streamingContent != null;

  List<int> get _retrievedChunkIds {
    if (message?.retrievedChunkIds == null || message!.retrievedChunkIds!.isEmpty) {
      return [];
    }
    return message!.retrievedChunkIds!
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  Future<void> _loadSources() async {
    if (_sourceChunks != null || _loadingSources || _retrievedChunkIds.isEmpty) return;
    
    setState(() => _loadingSources = true);
    
    try {
      final vectorStore = getIt<ObjectBoxVectorStore>();
      final chunks = <Chunk>[];
      
      for (final id in _retrievedChunkIds.take(5)) { // Limit to 5 sources
        final chunk = await vectorStore.getById(id);
        if (chunk != null) {
          chunks.add(chunk);
        }
      }
      
      setState(() {
        _sourceChunks = chunks;
        _loadingSources = false;
      });
    } catch (e) {
      setState(() => _loadingSources = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shareContent(String text) {
    Share.share(text, subject: 'From EduMate');
  }

  void _showActionMenu(String content) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyToClipboard(content);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareContent(content);
                },
              ),
              if (!isUser && onRegenerate != null)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Regenerate'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRegenerate!();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.select_all),
                title: const Text('Select Text'),
                subtitle: const Text('Long-press text to select'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSources() {
    if (!_sourcesExpanded && _sourceChunks == null) {
      _loadSources();
    }
    setState(() => _sourcesExpanded = !_sourcesExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final content = streamingContent ?? message?.content ?? '';
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final colorScheme = Theme.of(context).colorScheme;
    final hasSources = !isUser && !isStreaming && _retrievedChunkIds.isNotEmpty;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: !isStreaming && content.isNotEmpty
            ? () => _showActionMenu(content)
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Card(
            color: isUser
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with label and action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isUser && !isStreaming)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'EduMate',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                            if (message?.confidenceScore != null &&
                                message!.confidenceScore! < 0.7) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Low confidence response',
                                child: Icon(
                                  Icons.warning_amber,
                                  size: 16,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      
                      // Action buttons (not shown during streaming)
                      if (!isStreaming && content.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionIcon(
                              icon: Icons.copy,
                              tooltip: 'Copy',
                              onTap: () => _copyToClipboard(content),
                            ),
                            const SizedBox(width: 4),
                            _ActionIcon(
                              icon: Icons.share,
                              tooltip: 'Share',
                              onTap: () => _shareContent(content),
                            ),
                            // Regenerate button - only for AI responses
                            if (!isUser && onRegenerate != null) ...[
                              const SizedBox(width: 4),
                              _ActionIcon(
                                icon: Icons.refresh,
                                tooltip: 'Regenerate',
                                onTap: onRegenerate!,
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  
                  if (!isUser && !isStreaming) const SizedBox(height: 8),
                  
                  // Selectable text content
                  SelectableRegion(
                    focusNode: FocusNode(),
                    selectionControls: MaterialTextSelectionControls(),
                    child: MarkdownBody(
                      data: content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(
                        p: Theme.of(context).textTheme.bodyMedium,
                        code: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              backgroundColor: colorScheme.surfaceContainerHighest,
                            ),
                        codeblockDecoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  if (isStreaming) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generating...',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Sources section (collapsible)
                  if (hasSources) ...[
                    const SizedBox(height: 8),
                    _buildSourcesSection(colorScheme),
                  ],
                  
                  if (!isStreaming && message?.timestamp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(message!.timestamp),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourcesSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleSources,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_retrievedChunkIds.length} source${_retrievedChunkIds.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _sourcesExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        
        if (_sourcesExpanded) ...[
          const SizedBox(height: 8),
          if (_loadingSources)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_sourceChunks != null && _sourceChunks!.isNotEmpty)
            ..._sourceChunks!.map((chunk) => _SourceCard(chunk: chunk))
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Sources not available',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final Chunk chunk;

  const _SourceCard({required this.chunk});

  String? _getChapterFromMetadata() {
    if (chunk.metadataJson == null || chunk.metadataJson!.isEmpty) return null;
    try {
      // Simple parsing for chapter info
      final json = chunk.metadataJson!;
      if (json.contains('chapter')) {
        final match = RegExp(r'"chapter"\s*:\s*"([^"]+)"').firstMatch(json);
        return match?.group(1);
      }
      if (json.contains('section_title')) {
        final match = RegExp(r'"section_title"\s*:\s*"([^"]+)"').firstMatch(json);
        return match?.group(1);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = chunk.content.length > 120
        ? '${chunk.content.substring(0, 120)}...'
        : chunk.content;
    
    final materialTitle = chunk.material.target?.title;
    final chapter = _getChapterFromMetadata();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material title
          if (materialTitle != null) ...[
            Row(
              children: [
                Icon(
                  Icons.menu_book,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    materialTitle,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          
          // Page, chapter, type badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (chunk.pageNumber != null)
                _MetadataBadge(
                  label: 'Page ${chunk.pageNumber}',
                  color: colorScheme.primaryContainer,
                  textColor: colorScheme.onPrimaryContainer,
                ),
              if (chapter != null)
                _MetadataBadge(
                  label: chapter,
                  color: colorScheme.tertiaryContainer,
                  textColor: colorScheme.onTertiaryContainer,
                ),
              _MetadataBadge(
                label: chunk.chunkType,
                color: colorScheme.secondaryContainer,
                textColor: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Content preview
          Text(
            preview,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.4,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MetadataBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

