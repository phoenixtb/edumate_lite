import 'dart:typed_data';
import 'package:mobx/mobx.dart';
import '../domain/entities/worksheet.dart';
import '../domain/services/worksheet_service.dart';
import '../domain/services/pdf_export_service.dart';
import '../config/service_locator.dart';

part 'worksheet_store.g.dart';

class WorksheetStore = WorksheetStoreBase with _$WorksheetStore;

abstract class WorksheetStoreBase with Store {
  final WorksheetService _worksheetService = getIt<WorksheetService>();
  final PdfExportService _pdfExportService = getIt<PdfExportService>();

  // === Configuration ===
  @observable
  ObservableList<int> selectedMaterialIds = ObservableList<int>();

  @observable
  int problemCount = 10;

  @observable
  int gradeLevel = 6;

  @observable
  String subject = 'math';

  @observable
  String? topic;

  @observable
  String difficulty = 'medium';

  @observable
  bool includeSteps = true;

  @observable
  bool includeAnswerKey = true;

  // === Generation State ===
  @observable
  Worksheet? currentWorksheet;

  @observable
  bool isGenerating = false;

  @observable
  double generationProgress = 0.0;

  @observable
  String? generationMessage;

  @observable
  String? error;

  // === Export State ===
  @observable
  bool isExporting = false;

  @observable
  Uint8List? exportedPdf;

  // === Computed ===
  @computed
  bool get canGenerate =>
      selectedMaterialIds.isNotEmpty && !isGenerating && !isExporting;

  @computed
  bool get canExport => currentWorksheet != null && !isExporting;

  @computed
  WorksheetConfig get config => WorksheetConfig(
        materialIds: selectedMaterialIds.toList(),
        problemCount: problemCount,
        gradeLevel: gradeLevel,
        subject: subject,
        topic: topic,
        difficulty: difficulty,
        includeSteps: includeSteps,
      );

  // === Actions ===

  @action
  void setSelectedMaterials(List<int> ids) {
    selectedMaterialIds = ObservableList.of(ids);
  }

  @action
  void addMaterial(int id) {
    if (!selectedMaterialIds.contains(id)) {
      selectedMaterialIds.add(id);
    }
  }

  @action
  void removeMaterial(int id) {
    selectedMaterialIds.remove(id);
  }

  @action
  void setProblemCount(int count) {
    problemCount = count.clamp(5, 20);
  }

  @action
  void setGradeLevel(int level) {
    gradeLevel = level.clamp(5, 10);
  }

  @action
  void setSubject(String value) {
    subject = value;
  }

  @action
  void setTopic(String? value) {
    topic = value?.isEmpty == true ? null : value;
  }

  @action
  void setDifficulty(String value) {
    difficulty = value;
  }

  @action
  void setIncludeSteps(bool value) {
    includeSteps = value;
  }

  @action
  void setIncludeAnswerKey(bool value) {
    includeAnswerKey = value;
  }

  @action
  void clearError() {
    error = null;
  }

  /// Generate worksheet from selected materials
  @action
  Future<void> generateWorksheet() async {
    if (!canGenerate) return;

    isGenerating = true;
    generationProgress = 0.0;
    generationMessage = 'Starting...';
    error = null;
    currentWorksheet = null;
    exportedPdf = null;

    final result = await _worksheetService.generateWorksheet(
      config,
      onProgress: (progress, message) {
        generationProgress = progress;
        generationMessage = message;
      },
    );

    result.fold(
      (failure) {
        error = failure.message;
        isGenerating = false;
        generationProgress = 0.0;
        generationMessage = null;
      },
      (worksheet) {
        currentWorksheet = worksheet;
        isGenerating = false;
        generationProgress = 1.0;
        generationMessage = 'Complete!';
      },
    );
  }

  /// Export current worksheet to PDF
  @action
  Future<Uint8List?> exportToPdf() async {
    if (!canExport) return null;

    isExporting = true;
    error = null;

    try {
      final bytes = await _pdfExportService.exportWorksheet(
        currentWorksheet!,
        includeAnswers: includeAnswerKey,
        includeSteps: includeSteps,
      );

      exportedPdf = bytes;
      isExporting = false;
      return bytes;
    } catch (e) {
      error = 'Export failed: $e';
      isExporting = false;
      return null;
    }
  }

  /// Reset all state
  @action
  void reset() {
    selectedMaterialIds.clear();
    problemCount = 10;
    gradeLevel = 6;
    subject = 'math';
    topic = null;
    difficulty = 'medium';
    includeSteps = true;
    includeAnswerKey = true;
    currentWorksheet = null;
    isGenerating = false;
    generationProgress = 0.0;
    generationMessage = null;
    error = null;
    isExporting = false;
    exportedPdf = null;
  }

  /// Clear current worksheet (to generate new one)
  @action
  void clearWorksheet() {
    currentWorksheet = null;
    exportedPdf = null;
    generationProgress = 0.0;
    generationMessage = null;
    error = null;
  }
}
