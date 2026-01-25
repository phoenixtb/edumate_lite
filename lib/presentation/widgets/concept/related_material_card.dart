import 'package:flutter/material.dart';
import '../../../domain/entities/material.dart' as app;
import '../../../domain/entities/concept.dart';

/// Card showing a related material with shared concepts
class RelatedMaterialCard extends StatelessWidget {
  final app.Material material;
  final List<Concept> sharedConcepts;
  final double relevanceScore;
  final VoidCallback? onTap;

  const RelatedMaterialCard({
    super.key,
    required this.material,
    this.sharedConcepts = const [],
    this.relevanceScore = 0.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceColor = _getSourceColor(material.sourceType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with relevance indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    sourceColor.withValues(alpha: 0.1),
                    sourceColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: sourceColor.withValues(alpha: 0.2),
                    child: Icon(
                      _getSourceIcon(material.sourceType),
                      color: sourceColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (material.subject != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.subject,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                material.subject!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Relevance badge
                  if (relevanceScore > 0) ...[
                    const SizedBox(width: 8),
                    _buildRelevanceBadge(context),
                  ],
                ],
              ),
            ),

            // Shared concepts
            if (sharedConcepts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.hub_outlined,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${sharedConcepts.length} shared concept${sharedConcepts.length > 1 ? 's' : ''}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sharedConcepts.take(5).map((concept) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            concept.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (sharedConcepts.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${sharedConcepts.length - 5} more',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
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

  Widget _buildRelevanceBadge(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (relevanceScore * 100).round();
    
    Color badgeColor;
    if (relevanceScore >= 0.7) {
      badgeColor = Colors.green;
    } else if (relevanceScore >= 0.4) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSourceIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'camera':
        return Icons.camera_alt;
      default:
        return Icons.description;
    }
  }

  Color _getSourceColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.blue;
      case 'camera':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
