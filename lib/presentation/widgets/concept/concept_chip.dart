import 'package:flutter/material.dart';
import '../../../domain/entities/concept.dart';

/// Styled chip for displaying concepts with type-based colors
class ConceptChip extends StatelessWidget {
  final Concept concept;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool showFrequency;
  final double? fontSize;

  const ConceptChip({
    super.key,
    required this.concept,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showFrequency = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getTypeColors(context, concept.type);
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getTypeIcon(concept.type),
                size: (fontSize ?? 13) + 2,
                color: selected ? Colors.white : colors.icon,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  concept.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : colors.text,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: fontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showFrequency && concept.frequency > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${concept.frequency}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected ? Colors.white : colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: (fontSize ?? 13) - 2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return Icons.person_outline;
      case 'formula':
        return Icons.functions;
      case 'theorem':
        return Icons.auto_awesome;
      case 'event':
        return Icons.event;
      case 'place':
        return Icons.place_outlined;
      case 'definition':
        return Icons.menu_book_outlined;
      case 'concept':
        return Icons.lightbulb_outline;
      case 'term':
      default:
        return Icons.label_outline;
    }
  }

  _ConceptColors _getTypeColors(BuildContext context, String type) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    switch (type.toLowerCase()) {
      case 'person':
        return _ConceptColors(
          primary: Colors.teal,
          background: isDark ? Colors.teal.shade900 : Colors.teal.shade50,
          border: isDark ? Colors.teal.shade700 : Colors.teal.shade200,
          text: isDark ? Colors.teal.shade100 : Colors.teal.shade800,
          icon: isDark ? Colors.teal.shade300 : Colors.teal.shade600,
        );
      case 'formula':
        return _ConceptColors(
          primary: Colors.purple,
          background: isDark ? Colors.purple.shade900 : Colors.purple.shade50,
          border: isDark ? Colors.purple.shade700 : Colors.purple.shade200,
          text: isDark ? Colors.purple.shade100 : Colors.purple.shade800,
          icon: isDark ? Colors.purple.shade300 : Colors.purple.shade600,
        );
      case 'theorem':
        return _ConceptColors(
          primary: Colors.indigo,
          background: isDark ? Colors.indigo.shade900 : Colors.indigo.shade50,
          border: isDark ? Colors.indigo.shade700 : Colors.indigo.shade200,
          text: isDark ? Colors.indigo.shade100 : Colors.indigo.shade800,
          icon: isDark ? Colors.indigo.shade300 : Colors.indigo.shade600,
        );
      case 'event':
        return _ConceptColors(
          primary: Colors.orange,
          background: isDark ? Colors.orange.shade900 : Colors.orange.shade50,
          border: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
          text: isDark ? Colors.orange.shade100 : Colors.orange.shade800,
          icon: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
        );
      case 'place':
        return _ConceptColors(
          primary: Colors.green,
          background: isDark ? Colors.green.shade900 : Colors.green.shade50,
          border: isDark ? Colors.green.shade700 : Colors.green.shade200,
          text: isDark ? Colors.green.shade100 : Colors.green.shade800,
          icon: isDark ? Colors.green.shade300 : Colors.green.shade600,
        );
      case 'definition':
        return _ConceptColors(
          primary: Colors.cyan,
          background: isDark ? Colors.cyan.shade900 : Colors.cyan.shade50,
          border: isDark ? Colors.cyan.shade700 : Colors.cyan.shade200,
          text: isDark ? Colors.cyan.shade100 : Colors.cyan.shade800,
          icon: isDark ? Colors.cyan.shade300 : Colors.cyan.shade600,
        );
      case 'concept':
        return _ConceptColors(
          primary: Colors.amber,
          background: isDark ? Colors.amber.shade900 : Colors.amber.shade50,
          border: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
          text: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
          icon: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
        );
      case 'term':
      default:
        return _ConceptColors(
          primary: Colors.blue,
          background: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
          border: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
          text: isDark ? Colors.blue.shade100 : Colors.blue.shade800,
          icon: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
        );
    }
  }
}

class _ConceptColors {
  final Color primary;
  final Color background;
  final Color border;
  final Color text;
  final Color icon;

  const _ConceptColors({
    required this.primary,
    required this.background,
    required this.border,
    required this.text,
    required this.icon,
  });
}

/// Type filter chip for filtering concepts by type
class ConceptTypeFilter extends StatelessWidget {
  final String type;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  const ConceptTypeFilter({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_getTypeLabel(type)),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'all':
        return 'All';
      case 'person':
        return 'People';
      case 'formula':
        return 'Formulas';
      case 'theorem':
        return 'Theorems';
      case 'event':
        return 'Events';
      case 'place':
        return 'Places';
      case 'definition':
        return 'Definitions';
      case 'concept':
        return 'Concepts';
      case 'term':
      default:
        return 'Terms';
    }
  }
}
