import 'dart:async';
import 'package:mobx/mobx.dart';
import '../domain/entities/ai_task.dart';
import '../infrastructure/services/notification_service.dart';
import '../core/utils/logger.dart';

part 'task_queue_store.g.dart';

class TaskQueueStore = TaskQueueStoreBase with _$TaskQueueStore;

/// Manages a priority queue of AI tasks
/// Ensures only one task runs at a time (model limitation)
abstract class TaskQueueStoreBase with Store {
  /// All tasks (pending, running, completed)
  @observable
  ObservableList<AITask> tasks = ObservableList<AITask>();

  /// Currently executing task
  @observable
  AITask? currentTask;

  /// Current task progress (0.0 to 1.0) - observable for UI
  @observable
  double currentProgress = 0.0;

  /// Whether the queue is processing
  @observable
  bool isProcessing = false;

  /// Maximum completed tasks to keep in history
  static const _maxHistory = 20;

  // Queue processing lock
  bool _processingLock = false;

  /// Pending tasks count
  @computed
  int get pendingCount => tasks.where((t) => t.status == TaskStatus.pending).length;

  /// Running tasks count (0 or 1)
  @computed
  int get runningCount => currentTask != null ? 1 : 0;

  /// Completed tasks count
  @computed
  int get completedCount => tasks.where((t) => t.status == TaskStatus.completed).length;

  /// Failed tasks count
  @computed
  int get failedCount => tasks.where((t) => t.status == TaskStatus.failed).length;

  /// Total active tasks (pending + running)
  @computed
  int get activeCount => pendingCount + runningCount;

  /// Whether there are any active tasks
  @computed
  bool get hasActiveTasks => activeCount > 0;

  /// Pending tasks sorted by priority
  @computed
  List<AITask> get pendingTasks {
    final pending = tasks.where((t) => t.status == TaskStatus.pending).toList();
    pending.sort((a, b) {
      // First by priority
      final priorityCompare = a.priority.value.compareTo(b.priority.value);
      if (priorityCompare != 0) return priorityCompare;
      // Then by creation time (FIFO)
      return a.createdAt.compareTo(b.createdAt);
    });
    return pending;
  }

  /// Recent completed/failed tasks
  @computed
  List<AITask> get recentTasks {
    return tasks
        .where((t) => t.status == TaskStatus.completed || t.status == TaskStatus.failed)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  }

  /// Enqueue a new task
  /// Returns the task ID
  @action
  String enqueue(AITask task) {
    tasks.add(task);
    AppLogger.info('📋 [QUEUE] Enqueued: ${task.typeName} - ${task.description}');
    
    // Start processing if not already
    _processNext();
    
    return task.id;
  }

  /// Cancel a pending task
  @action
  bool cancel(String taskId) {
    final task = tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('Task not found'),
    );

    if (task.status != TaskStatus.pending) {
      AppLogger.warning('⚠️ [QUEUE] Cannot cancel task in ${task.status} state');
      return false;
    }

    task.status = TaskStatus.cancelled;
    tasks.remove(task);
    AppLogger.info('🚫 [QUEUE] Cancelled: ${task.description}');
    return true;
  }

  /// Clear completed/failed tasks from history
  @action
  void clearHistory() {
    tasks.removeWhere((t) => 
      t.status == TaskStatus.completed || 
      t.status == TaskStatus.failed ||
      t.status == TaskStatus.cancelled
    );
  }

  /// Get task by ID
  AITask? getTask(String taskId) {
    try {
      return tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  /// Process the next task in queue
  Future<void> _processNext() async {
    // Prevent concurrent processing
    if (_processingLock || currentTask != null) return;
    
    final pending = pendingTasks;
    if (pending.isEmpty) return;

    _processingLock = true;
    
    try {
      final task = pending.first;
      await _executeTask(task);
    } finally {
      _processingLock = false;
      
      // Check for more tasks
      if (pendingTasks.isNotEmpty) {
        // Small delay before next task
        await Future.delayed(const Duration(milliseconds: 500));
        _processNext();
      }
    }
  }

  /// Execute a single task
  @action
  Future<void> _executeTask(AITask task) async {
    currentTask = task;
    currentProgress = 0.0; // Reset progress observable
    isProcessing = true;
    _lastDisplayedProgress = 0.0; // Reset throttle tracker
    
    // Update task state
    task.status = TaskStatus.running;
    task.startedAt = DateTime.now();
    task.progress = 0.0;
    
    AppLogger.info('▶️ [QUEUE] Starting: ${task.typeName} - ${task.description}');

    // Note: Session locking is handled internally by InferenceRouter.generate()
    // The queue only ensures tasks run sequentially (one at a time)

    try {
      // Execute the task and track progress
      await for (final progress in task.execute()) {
        _updateProgress(task, progress);
      }
      
      // Success
      _completeTask(task);
    } catch (e) {
      _failTask(task, e.toString());
    } finally {
      currentTask = null;
      isProcessing = false;
    }
  }

  // Track last displayed progress to throttle UI updates
  double _lastDisplayedProgress = 0.0;

  @action
  void _updateProgress(AITask task, double progress) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    task.progress = clampedProgress;
    
    // Only trigger UI update if progress changed by at least 2%
    // This prevents excessive rebuilds and BLASTBufferQueue errors
    if ((clampedProgress - _lastDisplayedProgress).abs() >= 0.02 || 
        clampedProgress >= 1.0) {
      _lastDisplayedProgress = clampedProgress;
      currentProgress = clampedProgress; // Update observable for FAB
      
      // Force list observable update for TaskQueueSheet
      final idx = tasks.indexOf(task);
      if (idx >= 0) {
        tasks[idx] = task;
      }
    }
  }

  @action
  void _completeTask(AITask task) {
    task.status = TaskStatus.completed;
    task.progress = 1.0;
    task.completedAt = DateTime.now();
    
    AppLogger.info('✅ [QUEUE] Completed: ${task.typeName} - ${task.description}');
    
    // Notify
    _notifyCompletion(task, true);
    task.onComplete?.call(true, null);
    
    // Trim history
    _trimHistory();
  }

  @action
  void _failTask(AITask task, String error) {
    task.status = TaskStatus.failed;
    task.error = error;
    task.completedAt = DateTime.now();
    
    AppLogger.error('❌ [QUEUE] Failed: ${task.typeName} - $error');
    
    // Notify
    _notifyCompletion(task, false);
    task.onComplete?.call(false, error);
    
    currentTask = null;
    isProcessing = false;
  }

  Future<void> _notifyCompletion(AITask task, bool success) async {
    // Don't notify for chat (user is watching)
    if (task.type == TaskType.chat) return;
    
    try {
      if (success) {
        await NotificationService.instance.showTaskComplete(
          taskType: task.typeName,
          description: task.description,
        );
      } else {
        await NotificationService.instance.showTaskFailed(
          taskType: task.typeName,
          error: task.error ?? 'Unknown error',
        );
      }
    } catch (e) {
      AppLogger.debug('Notification error: $e');
    }
  }

  void _trimHistory() {
    final completed = tasks
        .where((t) => t.status == TaskStatus.completed || t.status == TaskStatus.failed)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    
    if (completed.length > _maxHistory) {
      final toRemove = completed.skip(_maxHistory).toList();
      for (final task in toRemove) {
        tasks.remove(task);
      }
    }
  }
}
