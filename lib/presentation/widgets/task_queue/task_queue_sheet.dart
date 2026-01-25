import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import '../../../stores/task_queue_store.dart';
import '../../../domain/entities/ai_task.dart';

/// Bottom sheet showing task queue details
class TaskQueueSheet extends StatelessWidget {
  const TaskQueueSheet({super.key});

  static void show(BuildContext context) {
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        builder: (_) => const TaskQueueSheet(),
      );
    } catch (e) {
      // Context might be invalid, silently fail
      debugPrint('Failed to show TaskQueueSheet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GetIt.I<TaskQueueStore>();
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.queue, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'AI Task Queue',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Observer(
                      builder: (_) => store.recentTasks.isNotEmpty
                          ? TextButton(
                              onPressed: store.clearHistory,
                              child: const Text('Clear'),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Task list
              Expanded(
                child: Observer(
                  builder: (_) {
                    final current = store.currentTask;
                    final pending = store.pendingTasks;
                    final recent = store.recentTasks.take(10).toList();

                    if (current == null && pending.isEmpty && recent.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks in queue',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Current task
                        if (current != null) ...[
                          _SectionHeader(title: 'Running'),
                          _TaskTile(task: current, isRunning: true),
                          const SizedBox(height: 16),
                        ],

                        // Pending tasks
                        if (pending.isNotEmpty) ...[
                          _SectionHeader(title: 'Pending (${pending.length})'),
                          ...pending.map((t) => _TaskTile(
                            task: t,
                            onCancel: () => store.cancel(t.id),
                          )),
                          const SizedBox(height: 16),
                        ],

                        // Recent tasks
                        if (recent.isNotEmpty) ...[
                          _SectionHeader(title: 'Recent'),
                          ...recent.map((t) => _TaskTile(task: t)),
                        ],

                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final AITask task;
  final bool isRunning;
  final VoidCallback? onCancel;

  const _TaskTile({
    required this.task,
    this.isRunning = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = task.status == TaskStatus.failed;
    final isCompleted = task.status == TaskStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isFailed
          ? colorScheme.errorContainer.withOpacity(0.3)
          : isRunning
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status icon
                _buildStatusIcon(context),
                const SizedBox(width: 12),

                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.typeName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        task.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Actions
                if (onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onCancel,
                    tooltip: 'Cancel',
                  ),
              ],
            ),

            // Progress bar for running task
            if (isRunning) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                backgroundColor: colorScheme.primary.withOpacity(0.2),
              ),
              const SizedBox(height: 4),
              Text(
                '${(task.progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],

            // Error message
            if (isFailed && task.error != null) ...[
              const SizedBox(height: 8),
              Text(
                task.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Completion time
            if (isCompleted || isFailed) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(task.completedAt!),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;
    Widget? child;

    switch (task.status) {
      case TaskStatus.running:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: task.progress,
            strokeWidth: 2.5,
            color: colorScheme.primary,
          ),
        );
      case TaskStatus.pending:
        icon = Icons.schedule;
        color = colorScheme.outline;
      case TaskStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
      case TaskStatus.failed:
        icon = Icons.error;
        color = colorScheme.error;
      case TaskStatus.cancelled:
        icon = Icons.cancel;
        color = colorScheme.outline;
    }

    return Icon(icon, color: color, size: 24);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
