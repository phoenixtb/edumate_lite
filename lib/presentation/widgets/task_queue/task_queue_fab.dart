import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../stores/task_queue_store.dart';
import 'task_queue_sheet.dart';

/// Draggable floating action button showing task queue status
/// Shows progress ring and badge when tasks are active
/// User can drag to reposition
class TaskQueueFAB extends StatefulWidget {
  const TaskQueueFAB({super.key});

  @override
  State<TaskQueueFAB> createState() => _TaskQueueFABState();
}

class _TaskQueueFABState extends State<TaskQueueFAB> {
  static const _posXKey = 'task_queue_fab_x';
  static const _posYKey = 'task_queue_fab_y';

  Offset? _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_posXKey);
    final y = prefs.getDouble(_posYKey);
    if (x != null && y != null && mounted) {
      setState(() => _position = Offset(x, y));
    }
  }

  Future<void> _savePosition(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_posXKey, pos.dx);
    await prefs.setDouble(_posYKey, pos.dy);
  }

  @override
  Widget build(BuildContext context) {
    final store = GetIt.I<TaskQueueStore>();
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Observer(
      builder: (_) {
        // Hide when no active tasks and no recent failures
        if (!store.hasActiveTasks && store.failedCount == 0) {
          return const SizedBox.shrink();
        }

        final isRunning = store.currentTask != null;
        final hasPending = store.pendingCount > 0;
        final hasFailed = store.failedCount > 0;
        final progress = store.currentProgress; // Use dedicated observable

        // Default position: bottom-right, above bottom nav
        final defaultPos = Offset(
          screenSize.width - 70,
          screenSize.height - 180,
        );
        final pos = _position ?? defaultPos;

        // Clamp position to screen bounds
        final clampedPos = Offset(
          pos.dx.clamp(10, screenSize.width - 60),
          pos.dy.clamp(100, screenSize.height - 100),
        );

        return Positioned(
          left: clampedPos.dx,
          top: clampedPos.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  clampedPos.dx + details.delta.dx,
                  clampedPos.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (_) {
              setState(() => _isDragging = false);
              if (_position != null) {
                _savePosition(_position!);
              }
            },
            onTap: () => TaskQueueSheet.show(context),
            child: AnimatedScale(
              scale: _isDragging ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: hasFailed
                      ? colorScheme.errorContainer
                      : isRunning
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isDragging ? 0.3 : 0.15,
                      ),
                      blurRadius: _isDragging ? 12 : 6,
                      offset: Offset(0, _isDragging ? 4 : 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Progress ring (full circle background + progress arc)
                    if (isRunning) ...[
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          color: colorScheme.primary,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      // Percentage text
                      Text(
                        '${(progress * 100).toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ] else
                      Icon(
                        hasFailed ? Icons.error_outline : Icons.queue,
                        size: 24,
                        color: hasFailed
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),

                    // Badge for pending count
                    if (hasPending || hasFailed)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: hasFailed
                                ? colorScheme.error
                                : colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            '${hasFailed ? store.failedCount : store.pendingCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasFailed
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Inline task indicator for embedding in other widgets
class TaskQueueIndicator extends StatelessWidget {
  const TaskQueueIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GetIt.I<TaskQueueStore>();

    return Observer(
      builder: (_) {
        if (!store.hasActiveTasks) return const SizedBox.shrink();

        final task = store.currentTask;
        if (task == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => TaskQueueSheet.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value: task.progress,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(task.progress * 100).toInt()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text(
                  task.typeName,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (store.pendingCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '+${store.pendingCount}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
