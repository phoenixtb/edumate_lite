// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_queue_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TaskQueueStore on TaskQueueStoreBase, Store {
  Computed<int>? _$pendingCountComputed;

  @override
  int get pendingCount => (_$pendingCountComputed ??= Computed<int>(
    () => super.pendingCount,
    name: 'TaskQueueStoreBase.pendingCount',
  )).value;
  Computed<int>? _$runningCountComputed;

  @override
  int get runningCount => (_$runningCountComputed ??= Computed<int>(
    () => super.runningCount,
    name: 'TaskQueueStoreBase.runningCount',
  )).value;
  Computed<int>? _$completedCountComputed;

  @override
  int get completedCount => (_$completedCountComputed ??= Computed<int>(
    () => super.completedCount,
    name: 'TaskQueueStoreBase.completedCount',
  )).value;
  Computed<int>? _$failedCountComputed;

  @override
  int get failedCount => (_$failedCountComputed ??= Computed<int>(
    () => super.failedCount,
    name: 'TaskQueueStoreBase.failedCount',
  )).value;
  Computed<int>? _$activeCountComputed;

  @override
  int get activeCount => (_$activeCountComputed ??= Computed<int>(
    () => super.activeCount,
    name: 'TaskQueueStoreBase.activeCount',
  )).value;
  Computed<bool>? _$hasActiveTasksComputed;

  @override
  bool get hasActiveTasks => (_$hasActiveTasksComputed ??= Computed<bool>(
    () => super.hasActiveTasks,
    name: 'TaskQueueStoreBase.hasActiveTasks',
  )).value;
  Computed<List<AITask>>? _$pendingTasksComputed;

  @override
  List<AITask> get pendingTasks =>
      (_$pendingTasksComputed ??= Computed<List<AITask>>(
        () => super.pendingTasks,
        name: 'TaskQueueStoreBase.pendingTasks',
      )).value;
  Computed<List<AITask>>? _$recentTasksComputed;

  @override
  List<AITask> get recentTasks =>
      (_$recentTasksComputed ??= Computed<List<AITask>>(
        () => super.recentTasks,
        name: 'TaskQueueStoreBase.recentTasks',
      )).value;

  late final _$tasksAtom = Atom(
    name: 'TaskQueueStoreBase.tasks',
    context: context,
  );

  @override
  ObservableList<AITask> get tasks {
    _$tasksAtom.reportRead();
    return super.tasks;
  }

  @override
  set tasks(ObservableList<AITask> value) {
    _$tasksAtom.reportWrite(value, super.tasks, () {
      super.tasks = value;
    });
  }

  late final _$currentTaskAtom = Atom(
    name: 'TaskQueueStoreBase.currentTask',
    context: context,
  );

  @override
  AITask? get currentTask {
    _$currentTaskAtom.reportRead();
    return super.currentTask;
  }

  @override
  set currentTask(AITask? value) {
    _$currentTaskAtom.reportWrite(value, super.currentTask, () {
      super.currentTask = value;
    });
  }

  late final _$currentProgressAtom = Atom(
    name: 'TaskQueueStoreBase.currentProgress',
    context: context,
  );

  @override
  double get currentProgress {
    _$currentProgressAtom.reportRead();
    return super.currentProgress;
  }

  @override
  set currentProgress(double value) {
    _$currentProgressAtom.reportWrite(value, super.currentProgress, () {
      super.currentProgress = value;
    });
  }

  late final _$isProcessingAtom = Atom(
    name: 'TaskQueueStoreBase.isProcessing',
    context: context,
  );

  @override
  bool get isProcessing {
    _$isProcessingAtom.reportRead();
    return super.isProcessing;
  }

  @override
  set isProcessing(bool value) {
    _$isProcessingAtom.reportWrite(value, super.isProcessing, () {
      super.isProcessing = value;
    });
  }

  late final _$_executeTaskAsyncAction = AsyncAction(
    'TaskQueueStoreBase._executeTask',
    context: context,
  );

  @override
  Future<void> _executeTask(AITask task) {
    return _$_executeTaskAsyncAction.run(() => super._executeTask(task));
  }

  late final _$TaskQueueStoreBaseActionController = ActionController(
    name: 'TaskQueueStoreBase',
    context: context,
  );

  @override
  String enqueue(AITask task) {
    final _$actionInfo = _$TaskQueueStoreBaseActionController.startAction(
      name: 'TaskQueueStoreBase.enqueue',
    );
    try {
      return super.enqueue(task);
    } finally {
      _$TaskQueueStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  bool cancel(String taskId) {
    final _$actionInfo = _$TaskQueueStoreBaseActionController.startAction(
      name: 'TaskQueueStoreBase.cancel',
    );
    try {
      return super.cancel(taskId);
    } finally {
      _$TaskQueueStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearHistory() {
    final _$actionInfo = _$TaskQueueStoreBaseActionController.startAction(
      name: 'TaskQueueStoreBase.clearHistory',
    );
    try {
      return super.clearHistory();
    } finally {
      _$TaskQueueStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _updateProgress(AITask task, double progress) {
    final _$actionInfo = _$TaskQueueStoreBaseActionController.startAction(
      name: 'TaskQueueStoreBase._updateProgress',
    );
    try {
      return super._updateProgress(task, progress);
    } finally {
      _$TaskQueueStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _completeTask(AITask task) {
    final _$actionInfo = _$TaskQueueStoreBaseActionController.startAction(
      name: 'TaskQueueStoreBase._completeTask',
    );
    try {
      return super._completeTask(task);
    } finally {
      _$TaskQueueStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _failTask(AITask task, String error) {
    final _$actionInfo = _$TaskQueueStoreBaseActionController.startAction(
      name: 'TaskQueueStoreBase._failTask',
    );
    try {
      return super._failTask(task, error);
    } finally {
      _$TaskQueueStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
tasks: ${tasks},
currentTask: ${currentTask},
currentProgress: ${currentProgress},
isProcessing: ${isProcessing},
pendingCount: ${pendingCount},
runningCount: ${runningCount},
completedCount: ${completedCount},
failedCount: ${failedCount},
activeCount: ${activeCount},
hasActiveTasks: ${hasActiveTasks},
pendingTasks: ${pendingTasks},
recentTasks: ${recentTasks}
    ''';
  }
}
