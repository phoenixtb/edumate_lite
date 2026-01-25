import 'package:uuid/uuid.dart';

/// Types of AI tasks that can be queued
enum TaskType {
  chat,
  conceptExtraction,
  conceptExplanation,
  worksheetGeneration,
  materialProcessing,
}

/// Task execution status
enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

/// Priority levels for task scheduling
/// Lower number = higher priority
enum TaskPriority {
  high(0),    // Chat - user is waiting
  normal(1),  // Concept explanation
  low(2);     // Background extraction

  final int value;
  const TaskPriority(this.value);
}

/// Represents an AI task in the queue
class AITask {
  final String id;
  final TaskType type;
  final String description;
  final TaskPriority priority;
  final DateTime createdAt;
  
  TaskStatus status;
  double progress;
  String? error;
  DateTime? startedAt;
  DateTime? completedAt;
  
  /// The actual work to execute
  /// Returns a stream of progress updates (0.0 to 1.0)
  final Stream<double> Function() execute;
  
  /// Optional callback when task completes
  final void Function(bool success, String? error)? onComplete;
  
  /// Optional: associated material ID for notifications
  final int? materialId;
  final String? materialTitle;

  AITask({
    String? id,
    required this.type,
    required this.description,
    required this.execute,
    this.priority = TaskPriority.normal,
    this.onComplete,
    this.materialId,
    this.materialTitle,
  })  : id = id ?? const Uuid().v4(),
        createdAt = DateTime.now(),
        status = TaskStatus.pending,
        progress = 0.0;

  /// Display name for the task type
  String get typeName {
    switch (type) {
      case TaskType.chat:
        return 'Chat';
      case TaskType.conceptExtraction:
        return 'Concept Extraction';
      case TaskType.conceptExplanation:
        return 'Explaining Concept';
      case TaskType.worksheetGeneration:
        return 'Worksheet Generation';
      case TaskType.materialProcessing:
        return 'Processing Material';
    }
  }

  /// Icon name for the task type
  String get iconName {
    switch (type) {
      case TaskType.chat:
        return 'chat';
      case TaskType.conceptExtraction:
        return 'auto_awesome';
      case TaskType.conceptExplanation:
        return 'lightbulb';
      case TaskType.worksheetGeneration:
        return 'assignment';
      case TaskType.materialProcessing:
        return 'upload_file';
    }
  }

  /// Duration since task was created
  Duration get waitTime => DateTime.now().difference(createdAt);

  /// Duration the task ran (if started)
  Duration? get runTime {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  @override
  String toString() => 'AITask($id, $type, $status, ${(progress * 100).toInt()}%)';
}
