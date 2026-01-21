import 'package:flutter/material.dart';
import '../../../domain/entities/material.dart' as app_entities;

class MaterialCard extends StatelessWidget {
  final app_entities.Material material;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final void Function(String title, String? subject, int? gradeLevel)? onEdit;
  /// Whether concepts have been extracted for this material
  final bool hasConcepts;

  const MaterialCard({
    super.key,
    required this.material,
    this.onTap,
    this.onDelete,
    this.onRetry,
    this.onEdit,
    this.hasConcepts = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: _buildLeadingIcon(context),
          title: Text(material.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  if (material.subject != null) ...[
                    Chip(
                      label: Text(material.subject!),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (material.gradeLevel != null)
                    Text('Grade ${material.gradeLevel}'),
                ],
              ),
              const SizedBox(height: 4),
              _buildStatusRow(context),
            ],
          ),
          trailing: _buildTrailing(context),
          isThreeLine: true,
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    IconData icon;
    Color? color;

    switch (material.sourceType) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'image':
        icon = Icons.image;
        color = Colors.blue;
        break;
      case 'camera':
        icon = Icons.camera_alt;
        color = Colors.green;
        break;
      default:
        icon = Icons.description;
    }

    return CircleAvatar(
      backgroundColor: color?.withValues(alpha: 0.2),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    IconData icon;
    String text;
    Color? color;

    switch (material.status) {
      case 'completed':
        icon = Icons.check_circle;
        text = 'Ready to help • ${_formatDate(material.processedAt)}';
        color = Colors.green;
        break;
      case 'processing':
        icon = Icons.hourglass_empty;
        text = 'Processing...';
        color = Colors.orange;
        break;
      case 'failed':
        icon = Icons.error;
        text = 'Failed • ${material.errorMessage ?? "Unknown error"}';
        color = Colors.red;
        break;
      default:
        icon = Icons.pending;
        text = 'Pending';
        color = Colors.grey;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Show concept extraction indicator for completed materials
        if (material.status == 'completed' && !hasConcepts)
          Tooltip(
            message: 'Tap to extract concepts',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Extract',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (material.status == 'completed' && hasConcepts)
          Tooltip(
            message: 'Concepts extracted',
            child: Icon(
              Icons.lightbulb,
              size: 16,
              color: Colors.amber.shade600,
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }

  Widget? _buildTrailing(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') {
          await _showEditDialog(context);
        } else if (value == 'retry' && onRetry != null) {
          onRetry!();
        } else if (value == 'delete' && onDelete != null) {
          onDelete!();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Edit Details'),
            ],
          ),
        ),
        if (material.status == 'failed' && onRetry != null)
          const PopupMenuItem(
            value: 'retry',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18),
                SizedBox(width: 8),
                Text('Retry'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final titleController = TextEditingController(text: material.title);
    String? selectedSubject = material.subject;
    int? selectedGrade = material.gradeLevel;

    const subjects = ['math', 'science', 'history', 'english', 'other'];
    const grades = [5, 6, 7, 8, 9, 10, 11, 12];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...subjects.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s[0].toUpperCase() + s.substring(1)),
                        )),
                  ],
                  onChanged: (value) => setState(() => selectedSubject = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...grades.map((g) => DropdownMenuItem(
                          value: g,
                          child: Text('Grade $g'),
                        )),
                  ],
                  onChanged: (value) => setState(() => selectedGrade = value),
                ),
                const SizedBox(height: 12),
                // Show additional info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Info',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Source: ${material.sourceType.toUpperCase()}\n'
                        'Chunks: ${material.chunkCount}\n'
                        'Status: ${material.status}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Title cannot be empty')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && onEdit != null) {
      onEdit!(
        titleController.text.trim(),
        selectedSubject,
        selectedGrade,
      );
    }

    titleController.dispose();
  }
}
