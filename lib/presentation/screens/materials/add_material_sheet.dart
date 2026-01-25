import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/service_locator.dart';
import '../../../stores/material_store.dart';
import '../../../domain/services/material_processor.dart';

class AddMaterialSheet extends StatelessWidget {
  const AddMaterialSheet({super.key});

  static const List<String> _subjects = [
    'math',
    'science',
    'history',
    'english',
    'other',
  ];

  static const List<int> _grades = [5, 6, 7, 8, 9, 10, 11, 12];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.upload_file, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Study Material',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Choose a source to upload',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Options
            _OptionTile(
              icon: Icons.picture_as_pdf,
              iconColor: Colors.red,
              title: 'PDF Document',
              subtitle: 'Upload textbooks, notes, or worksheets',
              onTap: () => _pickPdf(context),
            ),

            _OptionTile(
              icon: Icons.image,
              iconColor: Colors.blue,
              title: 'From Gallery',
              subtitle: 'Select images of study materials',
              onTap: () => _pickImage(context),
            ),

            _OptionTile(
              icon: Icons.camera_alt,
              iconColor: Colors.purple,
              title: 'Take Photo',
              subtitle: 'Capture pages with your camera',
              onTap: () => _takePhoto(context),
            ),

            const SizedBox(height: 16),

            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final suggestedTitle = result.files.single.name.replaceAll('.pdf', '');

      if (!context.mounted) return;

      // Show metadata dialog first
      final metadata = await _showMetadataDialog(
        context,
        suggestedTitle: suggestedTitle,
        isPdf: true,
      );
      if (metadata == null) return; // User cancelled

      if (!context.mounted) return;

      // For PDFs, show processing mode dialog
      final mode = await _showProcessingModeDialog(context);
      if (mode == null) return; // User cancelled

      if (!context.mounted) return;

      // Show snackbar
      _showProcessingSnackbar(
        context,
        metadata.title,
        isThorough: mode == ProcessingMode.thorough,
      );

      // Close the sheet
      Navigator.pop(context);

      // Start processing
      final materialStore = getIt<MaterialStore>();
      materialStore.processMaterial(
        MaterialInput(
          title: metadata.title,
          sourceType: 'pdf',
          content: file.path,
          subject: metadata.subject,
          gradeLevel: metadata.gradeLevel,
          processingMode: mode,
        ),
      );
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);

    if (result != null && context.mounted) {
      final suggestedTitle =
          'Image ${DateTime.now().toString().substring(0, 10)}';

      // Show metadata dialog
      final metadata = await _showMetadataDialog(
        context,
        suggestedTitle: suggestedTitle,
      );
      if (metadata == null) return;

      if (!context.mounted) return;

      _showProcessingSnackbar(context, metadata.title);
      Navigator.pop(context);

      final materialStore = getIt<MaterialStore>();
      materialStore.processMaterial(
        MaterialInput(
          title: metadata.title,
          sourceType: 'image',
          content: result.path,
          subject: metadata.subject,
          gradeLevel: metadata.gradeLevel,
        ),
      );
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera);

    if (result != null && context.mounted) {
      final suggestedTitle =
          'Photo ${DateTime.now().toString().substring(0, 10)}';

      // Show metadata dialog
      final metadata = await _showMetadataDialog(
        context,
        suggestedTitle: suggestedTitle,
      );
      if (metadata == null) return;

      if (!context.mounted) return;

      _showProcessingSnackbar(context, metadata.title);
      Navigator.pop(context);

      final materialStore = getIt<MaterialStore>();
      materialStore.processMaterial(
        MaterialInput(
          title: metadata.title,
          sourceType: 'camera',
          content: result.path,
          subject: metadata.subject,
          gradeLevel: metadata.gradeLevel,
        ),
      );
    }
  }

  /// Show metadata dialog for title, subject, grade
  Future<_MaterialMetadata?> _showMetadataDialog(
    BuildContext context, {
    required String suggestedTitle,
    bool isPdf = false,
  }) {
    final titleController = TextEditingController(text: suggestedTitle);
    String? selectedSubject;
    int? selectedGrade;

    return showDialog<_MaterialMetadata>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Material Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter a descriptive title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                  ),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(_capitalizeSubject(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedSubject = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: _grades
                      .map(
                        (g) =>
                            DropdownMenuItem(value: g, child: Text('Grade $g')),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedGrade = value),
                ),
                if (isPdf) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You\'ll choose processing mode next',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  _MaterialMetadata(
                    title: title,
                    subject: selectedSubject,
                    gradeLevel: selectedGrade,
                  ),
                );
              },
              child: Text(isPdf ? 'Next' : 'Process'),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeSubject(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Show dialog for user to choose processing mode
  Future<ProcessingMode?> _showProcessingModeDialog(BuildContext context) {
    return showDialog<ProcessingMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Processing Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how to process this PDF:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _ProcessingModeOption(
              icon: Icons.speed,
              title: 'Fast',
              subtitle: 'Quick text extraction. Best for text-based PDFs.',
              color: Colors.green,
              onTap: () => Navigator.pop(ctx, ProcessingMode.fast),
            ),
            const SizedBox(height: 12),
            _ProcessingModeOption(
              icon: Icons.auto_awesome,
              title: 'Thorough (AI Vision)',
              subtitle:
                  'Uses AI to read each page. Better for scanned docs, equations, diagrams. Slower.',
              color: Colors.purple,
              onTap: () => Navigator.pop(ctx, ProcessingMode.thorough),
              warningText:
                  'Note: AI may slightly rephrase content during extraction.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showProcessingSnackbar(
    BuildContext context,
    String title, {
    bool isThorough = false,
  }) {
    final message = isThorough
        ? 'Processing "$title" with AI Vision...'
        : 'Processing "$title"...';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: isThorough ? 5 : 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Internal class to hold metadata from dialog
class _MaterialMetadata {
  final String title;
  final String? subject;
  final int? gradeLevel;

  _MaterialMetadata({required this.title, this.subject, this.gradeLevel});
}

/// Widget for processing mode selection
class _ProcessingModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? warningText;

  const _ProcessingModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (warningText != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              warningText!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
