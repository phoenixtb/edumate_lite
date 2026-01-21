import 'dart:convert';
import 'package:mobx/mobx.dart';
import '../domain/entities/material.dart';
import 'processing_state.dart';
import '../domain/services/material_processor.dart';
import '../infrastructure/database/objectbox.dart';
import '../config/service_locator.dart';

part 'material_store.g.dart';

/// Callback for when scanned PDF is detected
typedef ScannedPdfCallback = Future<bool> Function(String message, MaterialInput input);

class MaterialStore = MaterialStoreBase with _$MaterialStore;

abstract class MaterialStoreBase with Store {
  final MaterialProcessor _materialProcessor = getIt<MaterialProcessor>();
  final ObjectBoxManager _objectBox = getIt<ObjectBoxManager>();

  @observable
  ObservableList<Material> materials = ObservableList<Material>();

  @observable
  bool isLoading = false;

  @observable
  String? error;

  /// Pending scanned PDF that needs user decision
  @observable
  MaterialInput? pendingScannedPdfInput;

  /// Message for pending scanned PDF
  @observable
  String? pendingScannedPdfMessage;

  /// Material ID for pending scanned PDF (to delete if user chooses vision mode)
  @observable
  int? pendingScannedPdfMaterialId;

  @action
  void clearError() {
    error = null;
  }

  @action
  void clearPendingScannedPdf() {
    pendingScannedPdfInput = null;
    pendingScannedPdfMessage = null;
    pendingScannedPdfMaterialId = null;
  }

  /// Map of ongoing processing jobs
  /// Key: temp ID, Value: ProcessingState
  @observable
  ObservableMap<int, ProcessingState> processingJobs = ObservableMap();

  @action
  Future<void> loadMaterials() async {
    isLoading = true;
    error = null;

    try {
      final allMaterials = _objectBox.materialBox.getAll();
      materials = ObservableList.of(allMaterials);
      isLoading = false;
    } catch (e) {
      error = 'Failed to load materials: $e';
      isLoading = false;
    }
  }

  @action
  Future<void> processMaterial(MaterialInput input) async {
    error = null;

    // Create temp material for tracking
    final tempMaterial = Material(
      title: input.title,
      sourceType: input.sourceType,
      subject: input.subject,
      gradeLevel: input.gradeLevel,
      status: 'processing',
    );
    
    // Create unique temp ID
    final tempId = DateTime.now().millisecondsSinceEpoch;
    
    // Create processing state
    final state = ProcessingState(tempMaterial, tempId);
    processingJobs[tempId] = state;

    try {
      // Process in background - UI stays responsive
      _materialProcessor.process(input).listen(
        (progress) {
          // Update state
          state.updateProgress(
            progress.progress,
            progress.message ?? '',
            progress.stage,
          );

          // Handle scanned PDF detection (special stage, not an error)
          if (progress.stage == 'scanned_pdf_detected') {
            state.updateProgress(
              progress.progress,
              progress.message ?? 'Scanned PDF detected',
              'scanned_pdf_detected',
            );
            
            // Store pending info for UI to show dialog
            pendingScannedPdfInput = input;
            pendingScannedPdfMessage = progress.message;
            pendingScannedPdfMaterialId = progress.material?.id;
            
            // Remove from processing jobs
            processingJobs.remove(tempId);
            return;
          }

          if (progress.error != null) {
            state.setError(progress.error!);
            error = progress.error;
            // Remove failed job after delay so user can see error
            Future.delayed(const Duration(seconds: 3), () {
              processingJobs.remove(tempId);
            });
            return;
          }

          if (progress.isComplete && progress.result != null) {
            state.complete();
            
            // Add completed material to list
            final existingIndex = materials.indexWhere((m) => m.id == progress.result!.id);
            if (existingIndex >= 0) {
              materials[existingIndex] = progress.result!;
            } else {
              materials.add(progress.result!);
            }
            
            // Remove from processing jobs after small delay for UI feedback
            Future.delayed(const Duration(milliseconds: 500), () {
              processingJobs.remove(tempId);
            });
          }
        },
        onError: (e) {
          state.setError('Processing failed: $e');
          error = 'Processing failed: $e';
          // Remove failed job after delay
          Future.delayed(const Duration(seconds: 3), () {
            processingJobs.remove(tempId);
          });
        },
        cancelOnError: false,
      );
      
      // Return immediately - processing continues in background
    } catch (e) {
      state.setError('Processing failed: $e');
      error = 'Processing failed: $e';
      // Remove failed job after delay
      Future.delayed(const Duration(seconds: 3), () {
        processingJobs.remove(tempId);
      });
    }
  }

  /// Retry processing a scanned PDF with Vision mode
  @action
  Future<void> retryWithVisionMode() async {
    if (pendingScannedPdfInput == null) return;

    final input = pendingScannedPdfInput!;
    final materialId = pendingScannedPdfMaterialId;

    // Clear pending state
    clearPendingScannedPdf();

    // Delete the failed material if it exists
    if (materialId != null) {
      await _materialProcessor.deleteMaterial(materialId);
      materials.removeWhere((m) => m.id == materialId);
    }

    // Create new input with thorough mode
    final visionInput = MaterialInput(
      title: input.title,
      sourceType: input.sourceType,
      content: input.content,
      subject: input.subject,
      gradeLevel: input.gradeLevel,
      processingMode: ProcessingMode.thorough,
    );

    // Reprocess with vision
    await processMaterial(visionInput);
  }

  /// Cancel scanned PDF retry and keep the material as-is (partial extraction)
  @action
  void cancelScannedPdfRetry() {
    // Just clear the pending state, keep the material with whatever was extracted
    clearPendingScannedPdf();
    // Reload materials to show the one with scanned_detected status
    loadMaterials();
  }

  @action
  Future<void> deleteMaterial(int materialId) async {
    isLoading = true;
    error = null;

    final result = await _materialProcessor.deleteMaterial(materialId);

    result.fold(
      (failure) {
        error = failure.message;
        isLoading = false;
      },
      (_) {
        materials.removeWhere((m) => m.id == materialId);
        isLoading = false;
      },
    );
  }

  /// Update material metadata (title, subject, grade)
  @action
  Future<void> updateMaterial({
    required int materialId,
    required String title,
    String? subject,
    int? gradeLevel,
  }) async {
    error = null;

    try {
      // Find material in list
      final index = materials.indexWhere((m) => m.id == materialId);
      if (index < 0) {
        error = 'Material not found';
        return;
      }

      // Update in database
      final material = materials[index];
      material.title = title;
      material.subject = subject;
      material.gradeLevel = gradeLevel;
      _objectBox.materialBox.put(material);

      // Update in observable list (triggers UI refresh)
      materials[index] = material;
    } catch (e) {
      error = 'Failed to update material: $e';
    }
  }

  @action
  Future<void> reprocessMaterial(int materialId) async {
    error = null;
    
    // Get material
    final material = materials.firstWhere((m) => m.id == materialId);
    
    // Create temp ID
    final tempId = DateTime.now().millisecondsSinceEpoch;
    
    // Create processing state
    final state = ProcessingState(material, tempId);
    processingJobs[tempId] = state;

    try {
      _materialProcessor.reprocess(materialId).listen(
        (progress) {
          state.updateProgress(
            progress.progress,
            progress.message ?? '',
            progress.stage,
          );

          if (progress.error != null) {
            state.setError(progress.error!);
            error = progress.error;
            // Remove failed job after delay
            Future.delayed(const Duration(seconds: 3), () {
              processingJobs.remove(tempId);
            });
            return;
          }

          if (progress.isComplete && progress.result != null) {
            state.complete();
            
            final index = materials.indexWhere((m) => m.id == progress.result!.id);
            if (index >= 0) {
              materials[index] = progress.result!;
            }
            
            Future.delayed(const Duration(milliseconds: 500), () {
              processingJobs.remove(tempId);
            });
          }
        },
        onError: (e) {
          state.setError('Reprocessing failed: $e');
          error = 'Reprocessing failed: $e';
          // Remove failed job after delay
          Future.delayed(const Duration(seconds: 3), () {
            processingJobs.remove(tempId);
          });
        },
        cancelOnError: false,
      );
    } catch (e) {
      state.setError('Reprocessing failed: $e');
      error = 'Reprocessing failed: $e';
      // Remove failed job after delay
      Future.delayed(const Duration(seconds: 3), () {
        processingJobs.remove(tempId);
      });
    }
  }

  @computed
  List<Material> get completedMaterials =>
      materials.where((m) => m.status == 'completed').toList();

  @computed
  List<Material> get failedMaterials =>
      materials.where((m) => m.status == 'failed').toList();

  @computed
  List<Material> get processingMaterials =>
      materials.where((m) => m.status == 'processing').toList();

  @computed
  int get totalChunks =>
      materials.fold(0, (sum, m) => sum + m.chunkCount);
  
  @computed
  bool get hasProcessingJobs => processingJobs.isNotEmpty;
  
  @computed
  int get processingJobsCount => processingJobs.length;

  /// Add text content as a material (for scanned notes, etc.)
  /// This uses the text input adapter which directly processes the string
  @action
  void addTextMaterial({
    required String title,
    required String content,
    String sourceType = 'text',
    String? subject,
    int? gradeLevel,
  }) {
    final input = MaterialInput(
      title: title,
      sourceType: sourceType,
      content: content, // TextInputAdapter handles raw strings
      subject: subject,
      gradeLevel: gradeLevel,
    );
    
    processMaterial(input);
  }

  /// Get materials related to a given material
  /// Based on shared keywords/topics and subject
  List<Material> getRelatedMaterials(int materialId, {int limit = 5}) {
    final material = materials.firstWhere(
      (m) => m.id == materialId,
      orElse: () => Material(title: '', sourceType: ''),
    );
    if (material.id == 0) return [];

    // Get keywords from this material
    final keywords = _parseKeywords(material.keywordsJson);
    final topics = _parseKeywords(material.detectedTopicsJson);

    // Score other materials based on overlap
    final scored = <MapEntry<Material, double>>[];

    for (final other in materials) {
      if (other.id == materialId || other.status != 'completed') continue;

      double score = 0.0;

      // Subject match (high weight)
      if (material.subject != null &&
          material.subject == other.subject) {
        score += 0.4;
      }

      // Grade level proximity
      if (material.gradeLevel != null && other.gradeLevel != null) {
        final diff = (material.gradeLevel! - other.gradeLevel!).abs();
        if (diff == 0) {
          score += 0.2;
        } else if (diff == 1) {
          score += 0.1;
        }
      }

      // Keyword overlap
      final otherKeywords = _parseKeywords(other.keywordsJson);
      final keywordOverlap = keywords
          .where((k) => otherKeywords.contains(k))
          .length;
      if (keywords.isNotEmpty) {
        score += 0.2 * (keywordOverlap / keywords.length);
      }

      // Topic overlap
      final otherTopics = _parseKeywords(other.detectedTopicsJson);
      final topicOverlap = topics
          .where((t) => otherTopics.contains(t))
          .length;
      if (topics.isNotEmpty) {
        score += 0.2 * (topicOverlap / topics.length);
      }

      if (score > 0.1) {
        scored.add(MapEntry(other, score));
      }
    }

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(limit).map((e) => e.key).toList();
  }

  Set<String> _parseKeywords(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return Set<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return {};
    }
  }
}

