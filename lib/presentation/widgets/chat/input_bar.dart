import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../common/image_picker_button.dart';

class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(Uint8List imageBytes, String question)? onSendImage;
  final bool isLoading;
  final bool showSuggestions;
  final bool showImageAttachment;

  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onSendImage,
    this.isLoading = false,
    this.showSuggestions = true,
    this.showImageAttachment = true,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  bool _showQuickActions = true;
  Uint8List? _pendingImage;
  String? _pendingImageName;

  static const List<_QuickAction> _quickActions = [
    _QuickAction('Explain', Icons.lightbulb_outline, 'Explain this concept: '),
    _QuickAction('Summarize', Icons.short_text, 'Summarize: '),
    _QuickAction('Quiz me', Icons.quiz_outlined, 'Create a quiz about: '),
    _QuickAction('Examples', Icons.list_alt, 'Give examples of: '),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_showQuickActions == hasText) {
      setState(() => _showQuickActions = !hasText);
    }
  }

  void _applyQuickAction(_QuickAction action) {
    widget.controller.text = action.prefix;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    setState(() => _showQuickActions = false);
  }

  void _onImagePicked(Uint8List bytes, String? name) {
    setState(() {
      _pendingImage = bytes;
      _pendingImageName = name;
    });
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingImageName = null;
    });
  }

  void _sendWithImage() {
    if (_pendingImage != null && widget.onSendImage != null) {
      final question = widget.controller.text.trim().isNotEmpty
          ? widget.controller.text.trim()
          : 'Explain this image';
      widget.onSendImage!(_pendingImage!, question);
      widget.controller.clear();
      _clearPendingImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick action chips
            if (widget.showSuggestions && _showQuickActions && !widget.isLoading)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickActions.map((action) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: Icon(action.icon, size: 16),
                          label: Text(action.label),
                          onPressed: () => _applyQuickAction(action),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            
            // Pending image preview
            if (_pendingImage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _pendingImage!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pendingImageName ?? 'Image attached',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Type a question or send to explain',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _clearPendingImage,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image attachment button
                  if (widget.showImageAttachment && 
                      widget.onSendImage != null && 
                      _pendingImage == null &&
                      !widget.isLoading)
                    ImagePickerButton(
                      onImagePicked: _onImagePicked,
                      icon: Icons.attach_file,
                      tooltip: 'Attach image',
                    ),
                    
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: !widget.isLoading,
                      decoration: InputDecoration(
                        hintText: _pendingImage != null 
                            ? 'Ask about this image...'
                            : 'Ask a question...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: colorScheme.primary, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: _pendingImage == null
                            ? Icon(
                                Icons.auto_awesome,
                                color: colorScheme.primary.withOpacity(0.7),
                                size: 20,
                              )
                            : Icon(
                                Icons.image,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (widget.isLoading) return;
                        if (_pendingImage != null) {
                          _sendWithImage();
                        } else {
                          widget.onSend();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FilledButton(
                      onPressed: widget.isLoading 
                          ? null 
                          : (_pendingImage != null ? _sendWithImage : widget.onSend),
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        backgroundColor: colorScheme.primary,
                      ),
                      child: widget.isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(Icons.send, color: colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String prefix;

  const _QuickAction(this.label, this.icon, this.prefix);
}

