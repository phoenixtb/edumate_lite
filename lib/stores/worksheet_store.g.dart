// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worksheet_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WorksheetStore on WorksheetStoreBase, Store {
  Computed<bool>? _$canGenerateComputed;

  @override
  bool get canGenerate => (_$canGenerateComputed ??= Computed<bool>(
    () => super.canGenerate,
    name: 'WorksheetStoreBase.canGenerate',
  )).value;
  Computed<bool>? _$canExportComputed;

  @override
  bool get canExport => (_$canExportComputed ??= Computed<bool>(
    () => super.canExport,
    name: 'WorksheetStoreBase.canExport',
  )).value;
  Computed<WorksheetConfig>? _$configComputed;

  @override
  WorksheetConfig get config => (_$configComputed ??= Computed<WorksheetConfig>(
    () => super.config,
    name: 'WorksheetStoreBase.config',
  )).value;

  late final _$selectedMaterialIdsAtom = Atom(
    name: 'WorksheetStoreBase.selectedMaterialIds',
    context: context,
  );

  @override
  ObservableList<int> get selectedMaterialIds {
    _$selectedMaterialIdsAtom.reportRead();
    return super.selectedMaterialIds;
  }

  @override
  set selectedMaterialIds(ObservableList<int> value) {
    _$selectedMaterialIdsAtom.reportWrite(value, super.selectedMaterialIds, () {
      super.selectedMaterialIds = value;
    });
  }

  late final _$problemCountAtom = Atom(
    name: 'WorksheetStoreBase.problemCount',
    context: context,
  );

  @override
  int get problemCount {
    _$problemCountAtom.reportRead();
    return super.problemCount;
  }

  @override
  set problemCount(int value) {
    _$problemCountAtom.reportWrite(value, super.problemCount, () {
      super.problemCount = value;
    });
  }

  late final _$gradeLevelAtom = Atom(
    name: 'WorksheetStoreBase.gradeLevel',
    context: context,
  );

  @override
  int get gradeLevel {
    _$gradeLevelAtom.reportRead();
    return super.gradeLevel;
  }

  @override
  set gradeLevel(int value) {
    _$gradeLevelAtom.reportWrite(value, super.gradeLevel, () {
      super.gradeLevel = value;
    });
  }

  late final _$subjectAtom = Atom(
    name: 'WorksheetStoreBase.subject',
    context: context,
  );

  @override
  String get subject {
    _$subjectAtom.reportRead();
    return super.subject;
  }

  @override
  set subject(String value) {
    _$subjectAtom.reportWrite(value, super.subject, () {
      super.subject = value;
    });
  }

  late final _$topicAtom = Atom(
    name: 'WorksheetStoreBase.topic',
    context: context,
  );

  @override
  String? get topic {
    _$topicAtom.reportRead();
    return super.topic;
  }

  @override
  set topic(String? value) {
    _$topicAtom.reportWrite(value, super.topic, () {
      super.topic = value;
    });
  }

  late final _$difficultyAtom = Atom(
    name: 'WorksheetStoreBase.difficulty',
    context: context,
  );

  @override
  String get difficulty {
    _$difficultyAtom.reportRead();
    return super.difficulty;
  }

  @override
  set difficulty(String value) {
    _$difficultyAtom.reportWrite(value, super.difficulty, () {
      super.difficulty = value;
    });
  }

  late final _$includeStepsAtom = Atom(
    name: 'WorksheetStoreBase.includeSteps',
    context: context,
  );

  @override
  bool get includeSteps {
    _$includeStepsAtom.reportRead();
    return super.includeSteps;
  }

  @override
  set includeSteps(bool value) {
    _$includeStepsAtom.reportWrite(value, super.includeSteps, () {
      super.includeSteps = value;
    });
  }

  late final _$includeAnswerKeyAtom = Atom(
    name: 'WorksheetStoreBase.includeAnswerKey',
    context: context,
  );

  @override
  bool get includeAnswerKey {
    _$includeAnswerKeyAtom.reportRead();
    return super.includeAnswerKey;
  }

  @override
  set includeAnswerKey(bool value) {
    _$includeAnswerKeyAtom.reportWrite(value, super.includeAnswerKey, () {
      super.includeAnswerKey = value;
    });
  }

  late final _$currentWorksheetAtom = Atom(
    name: 'WorksheetStoreBase.currentWorksheet',
    context: context,
  );

  @override
  Worksheet? get currentWorksheet {
    _$currentWorksheetAtom.reportRead();
    return super.currentWorksheet;
  }

  @override
  set currentWorksheet(Worksheet? value) {
    _$currentWorksheetAtom.reportWrite(value, super.currentWorksheet, () {
      super.currentWorksheet = value;
    });
  }

  late final _$isGeneratingAtom = Atom(
    name: 'WorksheetStoreBase.isGenerating',
    context: context,
  );

  @override
  bool get isGenerating {
    _$isGeneratingAtom.reportRead();
    return super.isGenerating;
  }

  @override
  set isGenerating(bool value) {
    _$isGeneratingAtom.reportWrite(value, super.isGenerating, () {
      super.isGenerating = value;
    });
  }

  late final _$generationProgressAtom = Atom(
    name: 'WorksheetStoreBase.generationProgress',
    context: context,
  );

  @override
  double get generationProgress {
    _$generationProgressAtom.reportRead();
    return super.generationProgress;
  }

  @override
  set generationProgress(double value) {
    _$generationProgressAtom.reportWrite(value, super.generationProgress, () {
      super.generationProgress = value;
    });
  }

  late final _$generationMessageAtom = Atom(
    name: 'WorksheetStoreBase.generationMessage',
    context: context,
  );

  @override
  String? get generationMessage {
    _$generationMessageAtom.reportRead();
    return super.generationMessage;
  }

  @override
  set generationMessage(String? value) {
    _$generationMessageAtom.reportWrite(value, super.generationMessage, () {
      super.generationMessage = value;
    });
  }

  late final _$errorAtom = Atom(
    name: 'WorksheetStoreBase.error',
    context: context,
  );

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$isExportingAtom = Atom(
    name: 'WorksheetStoreBase.isExporting',
    context: context,
  );

  @override
  bool get isExporting {
    _$isExportingAtom.reportRead();
    return super.isExporting;
  }

  @override
  set isExporting(bool value) {
    _$isExportingAtom.reportWrite(value, super.isExporting, () {
      super.isExporting = value;
    });
  }

  late final _$exportedPdfAtom = Atom(
    name: 'WorksheetStoreBase.exportedPdf',
    context: context,
  );

  @override
  Uint8List? get exportedPdf {
    _$exportedPdfAtom.reportRead();
    return super.exportedPdf;
  }

  @override
  set exportedPdf(Uint8List? value) {
    _$exportedPdfAtom.reportWrite(value, super.exportedPdf, () {
      super.exportedPdf = value;
    });
  }

  late final _$generateWorksheetAsyncAction = AsyncAction(
    'WorksheetStoreBase.generateWorksheet',
    context: context,
  );

  @override
  Future<void> generateWorksheet() {
    return _$generateWorksheetAsyncAction.run(() => super.generateWorksheet());
  }

  late final _$exportToPdfAsyncAction = AsyncAction(
    'WorksheetStoreBase.exportToPdf',
    context: context,
  );

  @override
  Future<Uint8List?> exportToPdf() {
    return _$exportToPdfAsyncAction.run(() => super.exportToPdf());
  }

  late final _$WorksheetStoreBaseActionController = ActionController(
    name: 'WorksheetStoreBase',
    context: context,
  );

  @override
  void setSelectedMaterials(List<int> ids) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setSelectedMaterials',
    );
    try {
      return super.setSelectedMaterials(ids);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void addMaterial(int id) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.addMaterial',
    );
    try {
      return super.addMaterial(id);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void removeMaterial(int id) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.removeMaterial',
    );
    try {
      return super.removeMaterial(id);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setProblemCount(int count) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setProblemCount',
    );
    try {
      return super.setProblemCount(count);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setGradeLevel(int level) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setGradeLevel',
    );
    try {
      return super.setGradeLevel(level);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSubject(String value) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setSubject',
    );
    try {
      return super.setSubject(value);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setTopic(String? value) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setTopic',
    );
    try {
      return super.setTopic(value);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setDifficulty(String value) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setDifficulty',
    );
    try {
      return super.setDifficulty(value);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIncludeSteps(bool value) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setIncludeSteps',
    );
    try {
      return super.setIncludeSteps(value);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIncludeAnswerKey(bool value) {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.setIncludeAnswerKey',
    );
    try {
      return super.setIncludeAnswerKey(value);
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.reset',
    );
    try {
      return super.reset();
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearWorksheet() {
    final _$actionInfo = _$WorksheetStoreBaseActionController.startAction(
      name: 'WorksheetStoreBase.clearWorksheet',
    );
    try {
      return super.clearWorksheet();
    } finally {
      _$WorksheetStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
selectedMaterialIds: ${selectedMaterialIds},
problemCount: ${problemCount},
gradeLevel: ${gradeLevel},
subject: ${subject},
topic: ${topic},
difficulty: ${difficulty},
includeSteps: ${includeSteps},
includeAnswerKey: ${includeAnswerKey},
currentWorksheet: ${currentWorksheet},
isGenerating: ${isGenerating},
generationProgress: ${generationProgress},
generationMessage: ${generationMessage},
error: ${error},
isExporting: ${isExporting},
exportedPdf: ${exportedPdf},
canGenerate: ${canGenerate},
canExport: ${canExport},
config: ${config}
    ''';
  }
}
