/// Application-wide constants
class AppConstants {
  AppConstants._();

  // AI Model Configuration (bundled assets)
  // EmbeddingGemma-300M (768-dimensional embeddings, 2048 token context)
  // From: litert-community/embeddinggemma-300m (PUBLIC - no auth needed)
  static const String embeddingModelAsset =
      'assets/models/embeddinggemma-300M_seq2048_mixed-precision.tflite';
  static const String embeddingTokenizerAsset =
      'assets/models/sentencepiece.model';

  // Gemma 3 Nano E2B (multimodal - text + vision)
  // From: google/gemma-3n-E2B-it-litert-preview (gated - needs access request)
  static const String inferenceModelAsset =
      'assets/models/gemma-3n-E2B-it-int4.task';

  // Phi-4 Mini Instruct (text-only, enhanced quality)
  // From: litert-community/Phi-4-mini-instruct (PUBLIC - no auth needed)
  // NOTE: Phi-4 has issues with MediaPipe template handling - use DeepSeek instead
  static const String phi4ModelUrl =
      'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.task';
  static const String phi4ModelName = 'Phi-4-mini-instruct';
  static const int phi4ModelSizeMb = 2500; // ~2.5GB

  // DeepSeek R1 Distill Qwen 1.5B (text-only, with thinking mode)
  // From: litert-community/DeepSeek-R1-Distill-Qwen-1.5B (PUBLIC - no auth needed)
  static const String deepseekModelUrl =
      'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/deepseek_q8_ekv1280.task';
  static const String deepseekModelName = 'DeepSeek-R1';
  static const int deepseekModelSizeMb = 1700; // ~1.7GB

  static const int embeddingDimension = 768;
  static const int maxEmbeddingTokens =
      2048; // EmbeddingGemma supports 2048 tokens
  static const int maxInferenceTokens = 2048;

  // Chunking Configuration (optimized for 2048-token embeddings)
  // Uses ACTUAL token counting from SentencePiece tokenizer
  // Model limit: 2048 | Prompt overhead: ~15 tokens | Safety buffer: ~200
  // Target: 1800 tokens (leaves 248-token buffer)
  static const int targetChunkSizeTokens =
      1800; // Target using actual tokenizer
  static const int maxChunkSizeTokens =
      1950; // Hard limit (with 98-token buffer)
  static const int chunkOverlapTokens = 150; // Overlap for continuity

  // RAG Configuration
  static const int retrievalTopK = 3; // Reduced from 5 for better focus
  static const double similarityThreshold = 0.5;
  static const int maxContextTokens = 2000;

  // Inference Sampling Configuration
  static const double inferenceTemperature = 0.4; // Lower for factual accuracy (default 0.8)
  static const int inferenceSamplingTopK = 20; // Sampling diversity

  // Conversation Configuration
  static const int maxContextMessages = 6;

  // File Size Limits
  static const int maxPdfSizeMb = 500; // Increased for textbooks
  static const int maxImageSizeMb = 10;
  static const int maxPdfPages = 3000; // Support full textbooks

  // Streaming Processing Configuration
  static const int pdfPageBatchSize = 10; // Process 10 pages at a time
  static const int embeddingBatchSize = 20; // Embed 20 chunks at a time
  static const int storageBatchSize = 50; // Store 50 chunks at a time

  // Storage Requirements
  static const int minRequiredStorageGb = 6;
  static const int embeddingModelSizeMb = 300;
  static const int inferenceModelSizeGb = 4;

  // UI Constants
  static const int messageAnimationDurationMs = 300;
}
