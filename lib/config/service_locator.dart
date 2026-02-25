import 'package:get_it/get_it.dart';
import '../infrastructure/database/objectbox.dart';
import '../infrastructure/database/objectbox_vector_store.dart';
import '../infrastructure/ai/gemma_embedding_provider.dart';
import '../infrastructure/chunking/token_validated_chunking_strategy.dart';
import '../infrastructure/input/pdf_input_adapter.dart';
import '../infrastructure/input/vision_pdf_adapter.dart';
import '../infrastructure/input/image_input_adapter.dart';
import '../infrastructure/input/camera_input_adapter.dart';
import '../infrastructure/input/text_input_adapter.dart';
import '../domain/services/rag_engine.dart';
import '../domain/services/conversation_manager.dart';
import '../domain/services/material_processor.dart';
import '../domain/services/ai_initialization_service.dart';
import '../domain/services/inference_router.dart';
import '../domain/services/worksheet_service.dart';
import '../domain/services/pdf_export_service.dart';
import '../stores/app_store.dart';
import '../stores/chat_store.dart';
import '../stores/material_store.dart';
import '../stores/model_download_store.dart';
import '../stores/worksheet_store.dart';
import '../stores/concept_store.dart';
import '../stores/task_queue_store.dart';
import '../domain/services/model_download_service.dart';

final getIt = GetIt.instance;

/// Setup all dependencies
Future<void> setupServiceLocator() async {
  // Database (singleton, initialized first)
  final objectBox = await ObjectBoxManager.create();
  getIt.registerSingleton<ObjectBoxManager>(objectBox);

  // Infrastructure - Database
  getIt.registerSingleton<ObjectBoxVectorStore>(
    ObjectBoxVectorStore(objectBox.store),
  );

  // Infrastructure - AI Providers
  getIt.registerLazySingleton<GemmaEmbeddingProvider>(
    () => GemmaEmbeddingProvider(),
  );

  // Infrastructure - Chunking (requires embedding provider for token counting)
  getIt.registerLazySingleton<TokenValidatedChunkingStrategy>(
    () => TokenValidatedChunkingStrategy(
      embeddingProvider: getIt<GemmaEmbeddingProvider>(),
    ),
  );

  // Infrastructure - Input Adapters
  getIt.registerLazySingleton<PdfInputAdapter>(() => PdfInputAdapter());
  getIt.registerLazySingleton<VisionPdfAdapter>(() => VisionPdfAdapter());
  getIt.registerLazySingleton<ImageInputAdapter>(() => ImageInputAdapter());
  getIt.registerLazySingleton<CameraInputAdapter>(() => CameraInputAdapter());
  getIt.registerLazySingleton<TextInputAdapter>(() => TextInputAdapter());

  // Inference Router (routes between Phi-4 and Gemma, manages model switching)
  getIt.registerLazySingleton<InferenceRouter>(
    () => InferenceRouter(),
  );

  // AI Initialization Service
  getIt.registerLazySingleton<AiInitializationService>(
    () => AiInitializationService(
      embeddingProvider: getIt<GemmaEmbeddingProvider>(),
      inferenceRouter: getIt<InferenceRouter>(),
    ),
  );

  // Domain Services
  getIt.registerLazySingleton<RagEngine>(
    () => RagEngine(
      embeddingProvider: getIt<GemmaEmbeddingProvider>(),
      vectorStore: getIt<ObjectBoxVectorStore>(),
      inferenceRouter: getIt<InferenceRouter>(),
    ),
  );

  getIt.registerLazySingleton<ConversationManager>(
    () => ConversationManager(
      conversationBox: objectBox.conversationBox,
      messageBox: objectBox.messageBox,
    ),
  );

  getIt.registerLazySingleton<MaterialProcessor>(
    () => MaterialProcessor(
      inputAdapters: [
        getIt<PdfInputAdapter>(),
        getIt<ImageInputAdapter>(),
        getIt<CameraInputAdapter>(),
        getIt<TextInputAdapter>(),
      ],
      chunkingStrategy: getIt<TokenValidatedChunkingStrategy>(),
      embeddingProvider: getIt<GemmaEmbeddingProvider>(),
      vectorStore: getIt<ObjectBoxVectorStore>(),
      materialBox: objectBox.materialBox,
      pageBox: objectBox.pageBox,
      conceptBox: objectBox.conceptBox,
      visionPdfAdapter: getIt<VisionPdfAdapter>(),
    ),
  );

  // Worksheet Services
  getIt.registerLazySingleton<WorksheetService>(
    () => WorksheetService(
      embeddingProvider: getIt<GemmaEmbeddingProvider>(),
      vectorStore: getIt<ObjectBoxVectorStore>(),
      inferenceRouter: getIt<InferenceRouter>(),
    ),
  );

  getIt.registerLazySingleton<PdfExportService>(
    () => PdfExportService(),
  );

  // Stores
  getIt.registerSingleton<AppStore>(AppStore());
  getIt.registerSingleton<ChatStore>(ChatStore());
  getIt.registerSingleton<MaterialStore>(MaterialStore());
  getIt.registerSingleton<ModelDownloadStore>(ModelDownloadStore());
  getIt.registerSingleton<WorksheetStore>(WorksheetStore());
  getIt.registerSingleton<ConceptStore>(ConceptStore(objectBox));
  getIt.registerSingleton<TaskQueueStore>(TaskQueueStore());

  // Model Download Service (bundled assets - no token needed)
  getIt.registerSingleton<ModelDownloadService>(
    ModelDownloadService(getIt<ModelDownloadStore>()),
  );
}
