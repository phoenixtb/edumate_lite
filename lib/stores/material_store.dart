import 'package:mobx/mobx.dart';
import '../domain/entities/material.dart';
import 'processing_state.dart';
import '../domain/services/material_processor.dart';
import '../infrastructure/database/objectbox.dart';
import '../config/service_locator.dart';

part 'material_store.g.dart';

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

  @action
  void clearError() {
    error = null;
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
}

