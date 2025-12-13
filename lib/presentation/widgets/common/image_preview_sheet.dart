import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Preview sheet for image before sending/processing
/// Used in chat attachments and OCR flow
class ImagePreviewSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final String? fileName;
  final bool showQuestionInput;
  final String defaultQuestion;
  final String sendButtonText;
  final void Function(String question)? onSend;
  final VoidCallback? onOCR;
  final VoidCallback? onCancel;

  const ImagePreviewSheet({
    super.key,
    required this.imageBytes,
    this.fileName,
    this.showQuestionInput = true,
    this.defaultQuestion = 'Explain this image',
    this.sendButtonText = 'Send',
    this.onSend,
    this.onOCR,
    this.onCancel,
  });

  /// Show as modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String? fileName,
    bool showQuestionInput = true,
    String defaultQuestion = 'Explain this image',
    String sendButtonText = 'Send',
    void Function(String question)? onSend,
    VoidCallback? onOCR,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImagePreviewSheet(
        imageBytes: imageBytes,
        fileName: fileName,
        showQuestionInput: showQuestionInput,
        defaultQuestion: defaultQuestion,
        sendButtonText: sendButtonText,
        onSend: onSend != null
            ? (q) {
                Navigator.pop(ctx);
                onSend(q);
              }
            : null,
        onOCR: onOCR != null
            ? () {
                Navigator.pop(ctx);
                onOCR();
              }
            : null,
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<ImagePreviewSheet> {
  late TextEditingController _questionController;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.defaultQuestion);
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Icon(Icons.image, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.fileName ?? 'Image Preview',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Question input (optional)
              if (widget.showQuestionInput && widget.onSend != null) ...[
                TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: 'Ask about this image...',
                    prefixIcon: const Icon(Icons.help_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                children: [
                  // OCR button (optional)
                  if (widget.onOCR != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOCR,
                        icon: const Icon(Icons.text_fields),
                        label: const Text('Extract Text'),
                      ),
                    ),

                  if (widget.onOCR != null && widget.onSend != null)
                    const SizedBox(width: 12),

                  // Send button
                  if (widget.onSend != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final question = _questionController.text.trim();
                          widget.onSend!(
                            question.isNotEmpty
                                ? question
                                : widget.defaultQuestion,
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: Text(widget.sendButtonText),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}





