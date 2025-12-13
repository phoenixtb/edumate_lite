import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Sheet showing OCR results with editing capabilities
class OCRResultSheet extends StatefulWidget {
  final String extractedText;
  final bool isLoading;
  final String? error;
  final void Function(String title, String content)? onSave;
  final void Function(String text)? onStartChat;
  final VoidCallback? onRetry;

  const OCRResultSheet({
    super.key,
    required this.extractedText,
    this.isLoading = false,
    this.error,
    this.onSave,
    this.onStartChat,
    this.onRetry,
  });

  /// Show as modal bottom sheet with edit support
  static Future<void> show(
    BuildContext context, {
    required String extractedText,
    bool isLoading = false,
    String? error,
    void Function(String title, String content)? onSave,
    void Function(String text)? onStartChat,
    VoidCallback? onRetry,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isLoading,
      enableDrag: !isLoading,
      builder: (ctx) => OCRResultSheet(
        extractedText: extractedText,
        isLoading: isLoading,
        error: error,
        onSave: onSave,
        onStartChat: onStartChat,
        onRetry: onRetry,
      ),
    );
  }

  @override
  State<OCRResultSheet> createState() => _OCRResultSheetState();
}

class _OCRResultSheetState extends State<OCRResultSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Scanned Notes');
    _contentController = TextEditingController(text: widget.extractedText);
    
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanges = _contentController.text != widget.extractedText ||
        _titleController.text != 'Scanned Notes';
    if (_hasChanges != hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  String get _currentText => _contentController.text;
  String get _currentTitle => _titleController.text.trim();

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareText() {
    Share.share(_currentText, subject: 'Extracted Text from EduMate');
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges && !_isValidContent) {
      return true; // No changes or no valid content, can close
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _handleClose() async {
    if (_isValidContent) {
      final shouldClose = await _confirmDiscard();
      if (shouldClose && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _handleSave() {
    if (widget.onSave != null && _isValidContent) {
      final title = _currentTitle.isNotEmpty ? _currentTitle : 'Scanned Notes';
      Navigator.pop(context);
      widget.onSave!(title, _currentText);
    }
  }

  void _handleStartChat() {
    if (widget.onStartChat != null && _isValidContent) {
      Navigator.pop(context);
      widget.onStartChat!(_currentText);
    }
  }

  bool get _isValidContent =>
      _currentText.isNotEmpty && !_currentText.startsWith('[');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleClose();
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.document_scanner, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Scanned Text',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_hasChanges)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Edited',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    const Spacer(),
                    if (!widget.isLoading && widget.error == null && _isValidContent) ...[
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy',
                        onPressed: _copyToClipboard,
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        tooltip: 'Share',
                        onPressed: _shareText,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: _handleClose,
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: _buildContent(scrollController),
              ),

              // Action buttons
              if (!widget.isLoading && widget.error == null && _isValidContent)
                _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Extracting text...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                widget.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_isValidContent && !_isEditing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.text_snippet_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                widget.extractedText.isEmpty
                    ? 'No text detected in image'
                    : widget.extractedText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title input
          Text(
            'Title',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter a title for this material',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              prefixIcon: const Icon(Icons.title, size: 20),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          
          const SizedBox(height: 20),
          
          // Content label with edit toggle
          Row(
            children: [
              Text(
                'Extracted Content',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.visibility : Icons.edit, size: 16),
                label: Text(_isEditing ? 'Preview' : 'Edit'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Content - editable or preview
          if (_isEditing)
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'Edit the extracted text...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              maxLines: null,
              minLines: 10,
              keyboardType: TextInputType.multiline,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: SelectableText(
                _currentText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap "Edit" to fix any OCR mistakes before saving',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Save to Materials
            if (widget.onSave != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleSave,
                  icon: const Icon(Icons.library_add),
                  label: const Text('Save Material'),
                ),
              ),
            if (widget.onSave != null && widget.onStartChat != null)
              const SizedBox(width: 12),
            // Start Chat
            if (widget.onStartChat != null)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _handleStartChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Ask AI'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
