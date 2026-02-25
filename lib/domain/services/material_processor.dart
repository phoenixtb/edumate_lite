import 'dart:async';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../interfaces/input_source.dart';
import '../interfaces/chunking_strategy.dart';
import '../interfaces/embedding_provider.dart';
import '../interfaces/vector_store.dart';
import '../entities/material.dart';
import '../entities/chunk.dart';
import '../entities/page.dart';
import '../entities/concept.dart';
import 'page_image_service.dart';
import 'keyword_extractor.dart';
import 'llm_concept_extractor.dart';
import 'inference_router.dart';
import '../../objectbox.g.dart' as obx;
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../infrastructure/services/notification_service.dart';
import '../../stores/app_store.dart';
import '../../config/service_locator.dart';

/// Material Processor
/// Orchestrates the full pipeline from input to indexed chunks
class MaterialProcessor {
  final List<InputSource> inputAdapters;
  final ChunkingStrategy chunkingStrategy;
  final EmbeddingProvider embeddingProvider;
  final VectorStore vectorStore;
  final obx.Box<Material> materialBox;
  final obx.Box<Page> pageBox;
  final obx.Box<Concept> conceptBox;

  /// Vision adapter for thorough PDF processing
  final InputSource? visionPdfAdapter;

  MaterialProcessor({
    required this.inputAdapters,
    required this.chunkingStrategy,
    required this.embeddingProvider,
    required this.vectorStore,
    required this.materialBox,
    required this.pageBox,
    required this.conceptBox,
    this.visionPdfAdapter,
  });

  /// Process a new material with chunking in background isolate
  Stream<ProcessingProgress> process(MaterialInput input) async* {
    final modeLabel = input.processingMode == ProcessingMode.thorough
        ? 'thorough/vision'
        : 'fast';
    AppLogger.info(
      '🎯 Starting material processing: "${input.title}" (${input.sourceType}, mode: $modeLabel)',
    );
    Material? material;

    try {
      // Create material entity with enhanced metadata
      material = Material(
        title: input.title,
        sourceType: input.sourceType,
        subject: input.subject,
        gradeLevel: input.gradeLevel,
        status: 'processing',
        processingMode: input.processingMode == ProcessingMode.thorough
            ? 'thorough'
            : 'fast',
      );

      final materialId = materialBox.put(material);
      material.id = materialId;

      AppLogger.debug('✅ Material entity created (ID: $materialId)');

      yield ProcessingProgress(
        progress: 0.05,
        stage: 'created',
        message: 'Material created',
        material: material,
      );

      // Track pages for Page entity creation
      final pageDataMap = <int, _PageData>{};

      // Find appropriate input adapter based on source type and processing mode
      InputSource? adapter;

      // For PDFs with thorough mode, use vision adapter if available
      if (input.sourceType == 'pdf' &&
          input.processingMode == ProcessingMode.thorough &&
          visionPdfAdapter != null) {
        adapter = visionPdfAdapter;
        AppLogger.info('📄 Using Vision PDF adapter for thorough processing');
      } else {
        // Standard adapter selection
        for (final a in inputAdapters) {
          if (a.sourceType == input.sourceType) {
            adapter = a;
            break;
          }
        }
      }

      if (adapter == null) {
        throw ProcessingException(
          'No adapter found for source type: ${input.sourceType}',
        );
      }

      // Extract content
      final extractMessage = input.processingMode == ProcessingMode.thorough
          ? 'Extracting content with AI Vision (this may take a while)...'
          : 'Extracting content...';
      yield ProcessingProgress(
        progress: 0.1,
        stage: 'extracting',
        message: extractMessage,
        material: material,
      );

      // INCREMENTAL PROCESSING: Process and store batches as they arrive
      final textBuffer = StringBuffer();
      int totalChunksProcessed = 0;
      int sequenceIndex = 0;

      await for (final extractProgress in adapter.extractContent(
        input.content,
      )) {
        // Handle errors, including scanned PDF detection
        if (extractProgress.error != null) {
          // Check if this is a scanned PDF detection (not a hard failure)
          if (extractProgress.error!.startsWith('SCANNED_PDF:')) {
            final message = extractProgress.error!.replaceFirst('SCANNED_PDF:', '');
            
            // Mark material as needing vision processing
            material.status = 'scanned_detected';
            material.errorMessage = message;
            materialBox.put(material);

            AppLogger.warning('⚠️ Scanned PDF detected: $message');

            // Yield special stage for UI to handle
            yield ProcessingProgress(
              progress: 0.3,
              stage: 'scanned_pdf_detected',
              message: message,
              material: material,
              error: null, // Not a failure, just needs user decision
            );
            return;
          }

          // Regular error
          material.status = 'failed';
          material.errorMessage = extractProgress.error;
          materialBox.put(material);

          yield ProcessingProgress(
            progress: 0,
            stage: 'extraction_failed',
            error: extractProgress.error,
            material: material,
          );
          return;
        }

        // Map extraction progress to 0.1-0.3
        yield ProcessingProgress(
          progress: 0.1 + (extractProgress.progress * 0.2),
          stage: 'extracting',
          message: extractProgress.currentPage ?? 'Extracting...',
          material: material,
        );

        // Collect page data for Page entity creation
        if (extractProgress.pageNumber != null) {
          final pageNum = extractProgress.pageNumber!;
          pageDataMap.putIfAbsent(
            pageNum,
            () => _PageData(
              pageNumber: pageNum,
              extractionMethod: extractProgress.extractionMethod ?? 'text',
              textDensity: extractProgress.textDensity ?? 1.0,
              width: extractProgress.pageWidth,
              height: extractProgress.pageHeight,
            ),
          );

          // Save page image if provided (vision mode)
          if (extractProgress.pageImageBytes != null &&
              extractProgress.pageImageBytes!.isNotEmpty) {
            final imagePath = await PageImageService.instance.savePageImage(
              materialId: material.id,
              pageNumber: pageNum,
              imageBytes: Uint8List.fromList(extractProgress.pageImageBytes!),
            );
            if (imagePath != null) {
              pageDataMap[pageNum]!.imagePath = imagePath;
            }
          }
        }

        // Update total pages count
        if (extractProgress.totalPages != null) {
          material.pageCount = extractProgress.totalPages!;
        }

        // Process batch of extracted text immediately
        if (extractProgress.extractedText != null &&
            extractProgress.extractedText!.trim().isNotEmpty) {
          final batchText = extractProgress.extractedText!;
          textBuffer.write(batchText);

          AppLogger.debug('🔪 Chunking batch (${batchText.length} chars)');

          // Chunk this batch (no longer in isolate - need async token counting)
          final batchChunkResults = await chunkingStrategy.chunk(batchText, {
            'sourceType': input.sourceType,
            'subject': input.subject,
          });

          AppLogger.debug(
            '✅ Got ${batchChunkResults.length} chunks from batch',
          );

          // Generate embeddings for this batch in smaller groups
          if (batchChunkResults.isNotEmpty) {
            // Process in smaller batches for better UX and stability
            final texts = batchChunkResults.map((r) => r.content).toList();

            for (
              int i = 0;
              i < texts.length;
              i += AppConstants.embeddingBatchSize
            ) {
              final end = (i + AppConstants.embeddingBatchSize < texts.length)
                  ? i + AppConstants.embeddingBatchSize
                  : texts.length;
              final batchTexts = texts.sublist(i, end);
              final batchNum = (i ~/ AppConstants.embeddingBatchSize) + 1;
              final totalBatches =
                  (texts.length / AppConstants.embeddingBatchSize).ceil();

              // Update progress before embedding
              yield ProcessingProgress(
                progress: 0.3 + (extractProgress.progress * 0.2),
                stage: 'embedding',
                message:
                    'Embedding batch $batchNum/$totalBatches (${batchTexts.length} chunks)...',
                material: material,
              );

              AppLogger.debug(
                '🔢 Embedding batch $batchNum/$totalBatches: '
                '${batchTexts.length} chunks [${i + 1}-$end/${texts.length}]',
              );

              final batchEmbeddings = await embeddingProvider.embedBatch(
                batchTexts,
              );

              // Create and store chunk entities immediately (free memory)
              final chunksToStore = <Chunk>[];
              final extractor = KeywordExtractor.instance;

              for (var j = 0; j < batchTexts.length; j++) {
                final chunkResult = batchChunkResults[i + j];
                final embedding = batchEmbeddings[j];

                // Extract keywords and entities for semantic enrichment
                final keywords = extractor.extractKeywords(
                  chunkResult.content,
                  maxKeywords: 8,
                );
                final entities = extractor.extractEntities(chunkResult.content);
                final conceptTags = extractor.extractConceptTags(
                  chunkResult.content,
                  maxTags: 5,
                );

                final chunk = Chunk(
                  content: chunkResult.content,
                  embedding: embedding,
                  pageNumber: chunkResult.pageNumber,
                  sectionIndex: chunkResult.sectionIndex,
                  sequenceIndex: sequenceIndex++,
                  chunkType: chunkResult.chunkType,
                  metadataJson: chunkResult.metadata.toString(),
                  keywordsJson: extractor.keywordsToJson(keywords),
                  entitiesJson: extractor.entitiesToJson(entities),
                  conceptTagsJson: extractor.keywordsToJson(conceptTags),
                  tokenCount: chunkResult.metadata['actual_tokens'] as int? ?? 0,
                  extractionMethod: input.processingMode == ProcessingMode.thorough ? 'vision' : 'text',
                  confidenceScore: input.processingMode == ProcessingMode.thorough ? 0.85 : 1.0,
                );

                chunk.material.target = material;
                chunksToStore.add(chunk);
              }

              // Store immediately after each batch (better memory management)
              AppLogger.debug(
                '💾 Storing ${chunksToStore.length} chunks from batch $batchNum',
              );
              final storedIds = await vectorStore.storeBatch(chunksToStore);

              // Optional: Extract concepts during processing if enabled
              final appStore = getIt<AppStore>();
              if (appStore.extractConceptsDuringProcessing) {
                try {
                  final router = getIt<InferenceRouter>();
                  final llmExtractor = LLMConceptExtractor(router);
                  
                  for (var idx = 0; idx < chunksToStore.length; idx++) {
                    final chunk = chunksToStore[idx];
                    final chunkId = storedIds[idx];
                    await llmExtractor.extractAndStore(
                      content: chunk.content,
                      materialId: material.id,
                      chunkId: chunkId,
                      subject: input.subject,
                    );
                  }
                  AppLogger.debug('💡 Extracted concepts from batch $batchNum');
                } catch (e) {
                  AppLogger.debug('⚠️ Concept extraction skipped: $e');
                }
              }

              totalChunksProcessed += chunksToStore.length;

              // Update progress after storing
              yield ProcessingProgress(
                progress: 0.3 + (extractProgress.progress * 0.2),
                stage: 'embedding',
                message:
                    'Stored batch $batchNum/$totalBatches (${totalChunksProcessed} total chunks)',
                material: material,
              );
            }
          }
        }
      }

      // Validate we got some content
      if (totalChunksProcessed == 0) {
        material.status = 'failed';
        material.errorMessage = 'No content extracted';
        materialBox.put(material);

        yield ProcessingProgress(
          progress: 0,
          stage: 'extraction_failed',
          error: 'No content could be extracted from the material',
          material: material,
        );
        return;
      }

      AppLogger.info(
        '✅ Total chunks processed and stored: $totalChunksProcessed',
      );

      // Save Page entities with metadata
      if (pageDataMap.isNotEmpty) {
        yield ProcessingProgress(
          progress: 0.95,
          stage: 'saving_pages',
          message: 'Saving page metadata...',
          material: material,
        );

        for (final pageData in pageDataMap.values) {
          final page = Page(
            pageNumber: pageData.pageNumber,
            imagePath: pageData.imagePath,
            width: pageData.width,
            height: pageData.height,
            extractionMethod: pageData.extractionMethod,
            textDensity: pageData.textDensity,
          );
          page.material.target = material;
          pageBox.put(page);
        }

        AppLogger.debug('💾 Saved ${pageDataMap.length} Page entities');
      }

      // Calculate extraction quality based on average text density
      if (pageDataMap.isNotEmpty) {
        final avgDensity = pageDataMap.values
                .map((p) => p.textDensity)
                .reduce((a, b) => a + b) /
            pageDataMap.length;
        material.extractionQuality = avgDensity.clamp(0.0, 1.0);
      }

      // All chunks already stored incrementally per-batch above

      // Update material with final count and metadata
      material.status = 'completed';
      material.processedAt = DateTime.now();
      material.chunkCount = totalChunksProcessed;
      materialBox.put(material);

      AppLogger.info(
        '🎉 Material processing completed: "${material.title}" ($totalChunksProcessed chunks)',
      );

      // Notify user to extract concepts
      try {
        await NotificationService.instance.showProcessingComplete(
          materialId: material.id,
          materialTitle: material.title,
        );
      } catch (e) {
        AppLogger.debug('⚠️ Notification skipped: $e');
      }

      yield ProcessingProgress(
        progress: 1.0,
        stage: 'completed',
        message: 'Processed $totalChunksProcessed chunks',
        isComplete: true,
        result: material,
        material: material,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ Material processing failed: "${input.title}"',
        e,
        stackTrace,
      );

      if (material != null) {
        material.status = 'failed';
        material.errorMessage = e.toString();
        materialBox.put(material);
        AppLogger.debug(
          'Material status updated to failed (ID: ${material.id})',
        );
      }

      yield ProcessingProgress(
        progress: 0,
        stage: 'failed',
        error: 'Processing failed: $e',
        material: material,
      );
    }
  }

  /// Reprocess a failed material
  Stream<ProcessingProgress> reprocess(int materialId) async* {
    try {
      final material = materialBox.get(materialId);
      if (material == null) {
        yield ProcessingProgress(
          progress: 0,
          stage: 'failed',
          error: 'Material not found',
        );
        return;
      }

      // Delete existing chunks
      await vectorStore.deleteByMaterial(materialId);

      // Reprocess with original path
      if (material.originalFilePath != null) {
        final input = MaterialInput(
          title: material.title,
          sourceType: material.sourceType,
          content: material.originalFilePath,
          subject: material.subject,
          gradeLevel: material.gradeLevel,
        );

        await for (final progress in process(input)) {
          yield progress;
        }
      } else {
        yield ProcessingProgress(
          progress: 0,
          stage: 'failed',
          error: 'Original file path not available',
        );
      }
    } catch (e) {
      yield ProcessingProgress(
        progress: 0,
        stage: 'failed',
        error: 'Reprocess failed: $e',
      );
    }
  }

  /// Delete material and its chunks, pages, page images, and concept references
  Future<Either<Failure, Unit>> deleteMaterial(int materialId) async {
    try {
      // Delete chunks
      await vectorStore.deleteByMaterial(materialId);

      // Delete page entities
      final pagesToDelete = pageBox
          .query(obx.Page_.material.equals(materialId))
          .build()
          .findIds();
      pageBox.removeMany(pagesToDelete);
      AppLogger.debug('🗑️ Deleted ${pagesToDelete.length} pages for material $materialId');

      // Delete page images from filesystem
      await PageImageService.instance.deleteForMaterial(materialId);

      // Clean up concept references
      await _cleanupConceptsForMaterial(materialId);

      // Delete material
      final removed = materialBox.remove(materialId);
      if (!removed) {
        return Left(StorageFailure('Material not found'));
      }

      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure('Failed to delete material: $e'));
    }
  }

  /// Remove material references from concepts, delete orphaned concepts
  Future<void> _cleanupConceptsForMaterial(int materialId) async {
    try {
      final allConcepts = conceptBox.getAll();
      
      int orphanedCount = 0;
      int updatedCount = 0;
      
      for (final concept in allConcepts) {
        if (!concept.appearsInMaterial(materialId)) continue;
        
        // Remove this material from concept's materialIds
        final materialIds = concept.materialIds;
        materialIds.remove(materialId);
        concept.materialIds = materialIds;
        
        if (materialIds.isEmpty) {
          // No more materials reference this concept - delete it
          conceptBox.remove(concept.id);
          orphanedCount++;
        } else {
          // Still has other material references - update it
          conceptBox.put(concept);
          updatedCount++;
        }
      }
      
      if (orphanedCount > 0 || updatedCount > 0) {
        AppLogger.debug(
          '🗑️ Concept cleanup for material $materialId: '
          '$orphanedCount deleted, $updatedCount updated',
        );
      }
    } catch (e) {
      AppLogger.warning('⚠️ Concept cleanup failed: $e');
      // Don't fail the delete - concepts are secondary
    }
  }
}

/// Processing mode for materials
enum ProcessingMode {
  /// Fast: Use programmatic text extraction (Syncfusion for PDFs)
  /// Best for: text-based PDFs, when speed matters
  fast,

  /// Thorough: Use AI Vision to process each page as an image
  /// Best for: scanned PDFs, complex layouts, equations, diagrams
  thorough,
}

/// Input for material processing
class MaterialInput {
  final String title;
  final String sourceType;
  final dynamic content; // File path, bytes, etc.
  final String? subject;
  final int? gradeLevel;

  /// Processing mode - affects extraction quality vs speed
  final ProcessingMode processingMode;

  MaterialInput({
    required this.title,
    required this.sourceType,
    required this.content,
    this.subject,
    this.gradeLevel,
    this.processingMode = ProcessingMode.fast,
  });
}

/// Progress update during processing
class ProcessingProgress {
  final double progress; // 0.0 to 1.0
  final String stage; // 'extracting', 'chunking', 'embedding', 'storing', etc.
  final String? message;
  final bool isComplete;
  final Material? result;
  final Material? material;
  final String? error;

  ProcessingProgress({
    required this.progress,
    required this.stage,
    this.message,
    this.isComplete = false,
    this.result,
    this.material,
    this.error,
  });
}

/// Helper class to collect page data during extraction
class _PageData {
  final int pageNumber;
  final String extractionMethod;
  final double textDensity;
  final double? width;
  final double? height;
  String? imagePath;

  _PageData({
    required this.pageNumber,
    required this.extractionMethod,
    required this.textDensity,
    this.width,
    this.height,
    this.imagePath,
  });
}
