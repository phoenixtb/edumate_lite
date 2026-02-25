# EduMate Lite — Native Android SRS

## Software Requirements Specification for Native Android Port

**Version:** 1.0  
**Date:** 2026-01-27  
**Purpose:** Enable a developer/LLM to build a native Android (Kotlin) clone of the Flutter EduMate Lite app, targeting performance-critical on-device AI workloads.

---

## 1. System Overview

EduMate Lite is an on-device AI educational assistant for grades 5–12. It processes study materials (PDF, images, camera captures), chunks and embeds them into a local vector database, and provides RAG-powered chat, concept extraction, worksheet generation, and a knowledge graph — all running entirely on-device with no cloud dependency.

### 1.1 Architecture

```
┌─────────────────────────────────────────────────┐
│                  Presentation                    │
│  Activities / Fragments / Compose UI / ViewModels│
├─────────────────────────────────────────────────┤
│                  Domain                          │
│  Entities, Use Cases, Repository Interfaces      │
├─────────────────────────────────────────────────┤
│                Infrastructure                    │
│  AI Providers, DB, Input Adapters, Chunking      │
├─────────────────────────────────────────────────┤
│                  Platform                        │
│  MediaPipe LLM, TFLite, ObjectBox, Android APIs  │
└─────────────────────────────────────────────────┘
```

**Pattern:** Clean Architecture + MVVM  
**DI:** Hilt (Dagger)  
**State:** Kotlin StateFlow / SharedFlow (or LiveData)  
**DB:** ObjectBox with HNSW vector index  
**AI Runtime:** MediaPipe LLM Inference API + TFLite  

---

## 2. AI Models & Runtime

### 2.1 Embedding Model

| Property | Value |
|---|---|
| Model | EmbeddingGemma-300M |
| Format | TFLite (.tflite) |
| File | `embeddinggemma-300M_seq2048_mixed-precision.tflite` |
| Size | ~300 MB |
| Tokenizer | SentencePiece (`sentencepiece.model`, ~5 MB) |
| Dimensions | 768 |
| Max Tokens | 2048 |
| Backend | GPU preferred, CPU fallback |
| Source | `https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/` |
| Auth | Public, no token needed |

**Native Integration:**
- Use the Google AI Edge SDK / LiteRT (TensorFlow Lite) Android API directly
- Load `.tflite` model via `Interpreter` or the MediaPipe Tasks API
- SentencePiece tokenizer via `com.google.android.gms.tflite.support` or a native JNI wrapper
- Must support: `embed(text)`, `embedBatch(texts)`, `countTokens(text)`

### 2.2 Primary Inference Model

| Property | Value |
|---|---|
| Model | Gemma 3 Nano E2B |
| Format | MediaPipe Task (.task) |
| File | `gemma-3n-E2B-it-int4.task` |
| Size | ~3.5 GB |
| Max Tokens | 2048 |
| Backend | GPU preferred, CPU fallback |
| Capabilities | Text + Vision (multimodal) |
| Sampling | Temperature 0.4, TopK 20 |
| Source | `https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/` |
| Auth | Gated — requires HuggingFace token + access request |

**Native Integration:**
- Use **MediaPipe LLM Inference API** (`com.google.mediapipe.tasks.genai.llminference`)
- Supports streaming token generation
- Supports image input for vision tasks
- Single-session: only one inference at a time (need a session manager/mutex)

### 2.3 Secondary Inference Model (Optional/Downloadable)

| Property | Value |
|---|---|
| Model | Qwen 2.5 1.5B Instruct |
| Format | MediaPipe Task (.task) |
| File | `Qwen2.5-1.5B-Instruct_multi-prefill_seq2048_kv2048.task` |
| Size | ~1.6 GB |
| Max Tokens | 1024 |
| Backend | CPU only |
| Capabilities | Text only (better at structured output) |
| Source | `https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/` |
| Auth | Public |

**Runtime model switching:** The app can switch between Gemma and Qwen at runtime. Only one model is loaded at a time. Gemma is the default; Qwen is downloaded on-demand from settings.

### 2.4 Model Manager Requirements

- Load/unload models at runtime
- Switch between Gemma ↔ Qwen (unload current, load new)
- Track which model is active
- Auto-switch: If vision is needed but current model is Qwen → switch to Gemma, then optionally switch back
- Session mutex: Only one inference call at a time across the entire app

---

## 3. Data Models (ObjectBox Entities)

### 3.1 Material

```kotlin
@Entity
data class Material(
    @Id var id: Long = 0,
    var title: String,
    var description: String? = null,
    var originalFilePath: String? = null,
    var sourceType: String,         // "pdf", "image", "camera", "text"
    var subject: String? = null,    // "math", "science", "history", "english", "other"
    var gradeLevel: Int? = null,    // 5-12
    var status: String = "pending", // "pending", "processing", "completed", "failed"
    var errorMessage: String? = null,
    var createdAt: Date,
    var processedAt: Date? = null,
    var lastAccessedAt: Date? = null,
    var chunkCount: Int = 0,
    var processingMode: String = "fast", // "fast", "thorough"
    var pageCount: Int = 0,
    var extractionQuality: Double = 0.0, // 0.0-1.0
    var fileHash: String? = null,
    var fileSizeBytes: Int? = null,
    var totalTokens: Int = 0,
    var totalWords: Int = 0,
    var language: String? = null,
    var detectedTopicsJson: String? = null,
    var keywordsJson: String? = null
)
```

### 3.2 Chunk

```kotlin
@Entity
data class Chunk(
    @Id var id: Long = 0,
    var content: String,
    @HnswIndex(dimensions = 768, neighborsPerNode = 30, indexingSearchCount = 200)
    var embedding: FloatArray? = null,  // 768-dim vector
    var pageNumber: Int? = null,
    var sectionIndex: Int? = null,
    var sequenceIndex: Int = 0,
    var chunkType: String = "paragraph", // "paragraph","heading","list","table","equation","definition","example"
    var wordCount: Int = 0,
    var metadataJson: String? = null,
    var tokenCount: Int = 0,
    var confidenceScore: Double = 1.0,
    var extractionMethod: String = "text", // "text", "vision"
    var startOffset: Int? = null,
    var endOffset: Int? = null,
    var importance: Double = 0.5,
    var isKeyPoint: Boolean = false,
    var keywordsJson: String? = null,
    var entitiesJson: String? = null,
    var conceptTagsJson: String? = null,   // For hybrid search (NOT displayed as concepts)
    var parentChunkId: Int? = null,
    var relatedChunkIdsJson: String? = null,
    var sentenceCount: Int = 0
) {
    lateinit var material: ToOne<Material>
}
```

**Important:** `conceptTagsJson` stores keywords for hybrid search matching. These are NOT the same as `Concept` entities in the Knowledge Graph. Do not display these as concepts.

### 3.3 Page

```kotlin
@Entity
data class Page(
    @Id var id: Long = 0,
    var pageNumber: Int,
    var imagePath: String? = null,
    var width: Double? = null,
    var height: Double? = null,
    var extractionMethod: String = "text", // "text", "vision", "hybrid"
    var textDensity: Double = 0.0,
    var hasEquations: Boolean = false,
    var hasDiagrams: Boolean = false,
    var hasTables: Boolean = false,
    var hasCode: Boolean = false,
    var summary: String? = null,
    var chunkCount: Int = 0,
    var createdAt: Date
) {
    lateinit var material: ToOne<Material>
}
```

### 3.4 Concept

```kotlin
@Entity
data class Concept(
    @Id var id: Long = 0,
    var name: String,
    @Index var normalizedName: String,  // lowercase, trimmed
    var type: String = "concept",       // "term","person","formula","theorem","concept","event","place","definition","keyword"
    var definition: String? = null,
    var materialIdsJson: String = "[]", // JSON array of material IDs
    var chunkIdsJson: String = "[]",
    var frequency: Int = 1,
    var relatedConceptIdsJson: String? = null,
    var subject: String? = null,
    var importance: Double = 0.5,
    var createdAt: Date,
    var updatedAt: Date? = null
)
```

**Important:** Concepts with `type == "keyword"` are metadata from rule-based extraction. They should be excluded from UI display (Knowledge Graph, concept counts). Only show LLM-extracted concepts (`type != "keyword"`).

### 3.5 Conversation

```kotlin
@Entity
data class Conversation(
    @Id var id: Long = 0,
    var title: String,
    var createdAt: Date,
    var updatedAt: Date,
    var messageCount: Int = 0
) {
    lateinit var material: ToOne<Material>
}
```

### 3.6 Message

```kotlin
@Entity
data class Message(
    @Id var id: Long = 0,
    var role: String,              // "user", "assistant", "system"
    var content: String,
    var retrievedChunkIds: String? = null,
    var confidenceScore: Double? = null,
    var timestamp: Date,
    var sequenceIndex: Int = 0
) {
    lateinit var conversation: ToOne<Conversation>
}
```

### 3.7 Entity Relationship Diagram

```
Material (1) ──── (*) Chunk       [cascade delete]
Material (1) ──── (*) Page        [cascade delete]
Material (1) ──── (*) Conversation
Conversation (1) ── (*) Message   [cascade delete]
Material (*) ──── (*) Concept     [via JSON ID arrays, manual cleanup]
```

---

## 4. Feature Specifications

### 4.1 Material Processing Pipeline

**Input Sources:**

| Source | Description | Library |
|---|---|---|
| PDF (text) | Syncfusion PDF text extraction with layout | Android PDF lib (PdfBox, iText, or Syncfusion Android SDK) |
| PDF (vision) | Render pages to images, OCR via Gemma Vision | Android `PdfRenderer` + MediaPipe Vision |
| Image | Gallery image OCR via Gemma Vision | MediaPipe Vision |
| Camera | Camera capture with preprocessing + OCR | CameraX + MediaPipe Vision |
| Text | Direct text input | N/A |

**Processing Flow:**

```
1. Input → Extract text (per page, streaming)
   ├── Text PDF: Extract text lines, group paragraphs (vertical gap > 15pt)
   │   └── Detect & fix spaced-character text (some PDFs encode "H e l l o")
   ├── Scanned PDF: Render pages → Vision OCR
   ├── Image: Preprocess → Vision OCR
   └── Camera: Enhance contrast → Vision OCR

2. Text → Chunk
   └── TokenValidatedChunkingStrategy:
       a. Accumulate paragraphs up to ~4000 chars
       b. Validate with actual token count (SentencePiece tokenizer)
       c. If > 1600 tokens → recursive binary split at sentence boundaries
       d. Add overlap of 200 chars between chunks

3. Chunk → Embed
   └── EmbeddingGemma-300M: batch embed all chunks (768-dim vectors)

4. Embed → Store
   └── ObjectBox: store chunks with HNSW-indexed embeddings

5. (Optional) Extract Keywords
   └── Rule-based keyword extraction for hybrid search tags (stored in conceptTagsJson)
   └── NOT displayed as concepts

6. (Optional, if setting enabled) Extract Concepts
   └── LLM-based concept extraction via inference model
   └── Stored as Concept entities in Knowledge Graph
```

**Scanned PDF Detection:**
- Extract full text quickly
- If < 50 chars/page average → scanned PDF
- Offer user to retry with vision mode (render pages as images, OCR each)

**Spaced-Character Fix:**
- Some PDFs encode text as individual glyphs: `H e l l o  W o r l d`
- Detect: Check if >30% of text sample matches pattern `([A-Za-z] ){3,}`
- Fix: Remove single spaces between characters, keep double spaces as word breaks

**Material Deletion Cascade:**
- Delete all chunks for the material (from ObjectBox)
- Delete all pages and their stored images
- Clean up Concept entities:
  - Remove materialId from concept's `materialIdsJson`
  - If no materialIds remain → delete the concept (orphan cleanup)

### 4.2 RAG Chat Engine

**Query Flow:**

```
1. User query → Embed query (EmbeddingGemma)
2. Vector search (HNSW, top-K=3, threshold=0.5)
   └── Optional: filter by selected material IDs
3. Re-rank results using BM25 + vector similarity hybrid scoring
4. Build context from top chunks (max 2000 tokens)
5. Build prompt: system prompt + context + conversation history + query
6. Generate response (streaming, token-by-token)
7. Store message + retrieved chunk IDs in conversation
```

**BM25 Hybrid Scoring:**
- `finalScore = 0.7 * vectorScore + 0.3 * bm25Score`
- BM25 params: k1=1.5, b=0.75
- Rerank top-K results after initial vector retrieval

**Conversation Context:**
- Include last 6 messages (3 turns) as conversation history
- Auto-generate conversation title from first user message via LLM

**Image Chat:**
- User can attach an image
- Use Gemma Vision to process: system prompt + image + query
- If current model is Qwen (no vision) → prompt to switch to Gemma

**Prompt Templates (see Section 7 for full prompts):**
- QA: Answer questions using provided material context
- Quiz: Generate multiple-choice questions
- Summary: Bullet points or paragraph
- Explain: Break down a concept
- Title: Generate short chat title

### 4.3 Concept Extraction & Knowledge Graph

**Two types of "concepts":**

1. **Keywords (type="keyword")**: Rule-based extraction (TF-IDF-like scoring + educational term boosting). Stored in Chunk's `conceptTagsJson` for hybrid search. NOT displayed in UI.

2. **LLM Concepts**: Extracted by the inference model when user enables "Extract Concepts During Processing" in settings. Stored as `Concept` entities. Displayed in Knowledge Graph and Material Detail.

**LLM Concept Extraction:**
- Send chunk text to inference model with a structured prompt
- Parse JSON response: `{concepts: [{name, type, importance}], relationships: [{from, to, relation}]}`
- Merge with existing concepts (deduplicate by `normalizedName`)
- Store relationships in `relatedConceptIdsJson`

**Knowledge Graph Display:**
- Graph visualization with nodes (concepts) and edges (relationships)
- Filter chips by concept type (term, formula, person, etc.)
- Only show concepts where `type != "keyword"`
- Tap node → show concept detail (definition, materials, frequency)

**Semantic Keyword Extraction (Experimental):**
- KeyBERT-style: Extract n-gram candidates → embed → cosine similarity to document → MMR for diversity
- Uses the same EmbeddingGemma model
- Currently a test/comparison feature, not integrated into main pipeline

### 4.4 Worksheet Generation

**Config:**
- Select materials (1+)
- Problem count (default 5)
- Grade level (5-12)
- Subject
- Topic (optional)
- Difficulty: easy / medium / hard / mixed
- Include steps: bool
- Include answer key: bool

**Flow:**
1. Embed a synthetic query based on config (topic + subject + grade)
2. Retrieve relevant chunks from selected materials
3. Build context from chunks
4. Send to inference model with WorksheetPromptTemplate
5. Parse JSON response: `[{question, answer, steps[], difficulty}]`
6. Display preview with expandable problem cards
7. Export to PDF (Syncfusion PDF generation with proper formatting)

### 4.5 Settings & Model Management

**Settings:**
- Theme mode (light/dark/system)
- Extract concepts during processing (bool)
- Developer mode (bool)

**Model Management:**
- Display status of each model (Gemma 3n, EmbeddingGemma, Qwen 2.5)
- Download Qwen 2.5 on-demand with progress
- Delete downloaded models
- Model size display

**Dev Tools (developer mode only):**
- Chunk browser: Search/filter all stored chunks, view metadata
- Storage breakdown: DB size, ML cache, images, etc.
- Model test: Switch models, test prompts, view raw output

### 4.6 Onboarding Flow

```
1. Welcome screen with app description
2. "Get Started" → trigger model loading:
   a. Install EmbeddingGemma from bundled assets (copy to app dir)
   b. Initialize EmbeddingGemma (load TFLite model)
   c. Initialize Gemma 3n inference (load MediaPipe model)
3. Show progress for each step
4. On completion → navigate to main app
```

---

## 5. UI Screens & Navigation

### 5.1 Navigation Structure

```
BottomNavigation (5 tabs):
├── [0] Home Tab
├── [1] Chat History
├── [2] Chat (center FAB, opens full-screen)
├── [3] Materials Library
└── [4] Settings

Floating: TaskQueueFAB (draggable, shows AI task progress)
```

### 5.2 Screen Specifications

| Screen | Description | Key Components |
|---|---|---|
| **Onboarding** | Model download/init progress | Progress indicators, step descriptions |
| **Home** | Dashboard with stats, quick actions, recent materials | Stats cards, action grid, horizontal material list |
| **Chat History** | List of conversations | Swipe delete, multi-select, timestamps |
| **Chat** | RAG conversation with streaming | Message bubbles, markdown rendering, math rendering, image attach, material filter, source chunk references |
| **Materials Library** | List of all materials with status | Material cards, processing progress, concept indicators |
| **Add Material** | Bottom sheet: source selection (PDF/Image/Camera) | File picker, camera, processing mode selector |
| **Material Detail** | 3-tab detail view | Overview (stats), Concepts (grid), Related (shared concepts) |
| **Knowledge Graph** | Interactive graph of concepts | Force-directed graph, type filter chips, node tap detail |
| **Worksheet Config** | Form to configure worksheet generation | Material picker, sliders, dropdowns |
| **Worksheet Preview** | Generated problems with answers | Expandable cards, export to PDF, share |
| **Settings** | App preferences, model status, dev tools | Toggle switches, model cards with download/delete |
| **Dev Tools** | 3-tab dev view | Chunk browser, storage stats, processing monitor |

### 5.3 Chat UI Details

**Message Bubble:**
- Markdown rendering with code blocks, bold, italic, lists
- LaTeX math rendering (`$inline$` and `$$block$$`)
- Source chunks expandable section (which materials were used)
- Copy, share, regenerate actions
- Streaming: append tokens character-by-character with cursor animation

**Input Bar:**
- Text field with send button
- Image attachment button (gallery/camera)
- Material filter button (select which materials to search)

### 5.4 Task Queue FAB

- Draggable floating action button
- Shows count of active tasks
- Progress ring animation
- Tap to expand task list (running, pending, completed, failed)
- Tasks: concept extraction, material processing, worksheet generation

---

## 6. Constants & Configuration

```kotlin
object AppConstants {
    // Embedding
    const val EMBEDDING_DIMENSION = 768
    const val MAX_EMBEDDING_TOKENS = 2048
    const val EMBEDDING_MODEL_FILE = "embeddinggemma-300M_seq2048_mixed-precision.tflite"
    const val EMBEDDING_TOKENIZER_FILE = "sentencepiece.model"

    // Inference
    const val INFERENCE_MODEL_FILE = "gemma-3n-E2B-it-int4.task"
    const val INFERENCE_TEMPERATURE = 0.4f
    const val INFERENCE_TOP_K = 20
    const val MAX_INFERENCE_TOKENS = 2048

    // Qwen (downloadable)
    const val QWEN_MODEL_URL = "https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill_seq2048_kv2048.task"
    const val QWEN_MAX_TOKENS = 1024

    // Chunking
    const val TARGET_CHUNK_SIZE_TOKENS = 1800
    const val MAX_CHUNK_SIZE_TOKENS = 1950
    const val CHUNK_OVERLAP_TOKENS = 150
    const val CHUNK_OVERLAP_CHARS = 200

    // RAG
    const val RETRIEVAL_TOP_K = 3
    const val SIMILARITY_THRESHOLD = 0.5f
    const val MAX_CONTEXT_TOKENS = 2000
    const val BM25_VECTOR_WEIGHT = 0.7f
    const val BM25_KEYWORD_WEIGHT = 0.3f

    // Conversation
    const val MAX_CONTEXT_MESSAGES = 6

    // File limits
    const val MAX_PDF_SIZE_MB = 500
    const val MAX_IMAGE_SIZE_MB = 10
    const val MAX_PDF_PAGES = 3000

    // Processing batches
    const val PDF_PAGE_BATCH_SIZE = 10
    const val EMBEDDING_BATCH_SIZE = 20
    const val STORAGE_BATCH_SIZE = 50
}
```

---

## 7. Prompt Templates

### 7.1 QA Prompt

```
System: You are EduMate, a friendly and knowledgeable educational tutor for students 
in grades 5 through 10. Answer questions using ONLY the provided study material. 
If the answer is not in the material, say so honestly.

Rules:
- Use simple, grade-appropriate language
- Give clear, step-by-step explanations when needed
- Use examples from the material when possible
- If unsure, say "Based on the provided material, I'm not sure about this"
- Use markdown formatting for better readability

Format your response as:
- Start with a brief, direct answer (1-2 sentences)
- Use **bold** for key terms and concepts
- Use bullet points for lists
- Use numbered steps for procedures
- Keep explanations concise but complete

Context from study materials:
{context}

Previous conversation:
{history}

Student's question: {query}
```

### 7.2 Quiz Prompt

```
System: Generate a quiz based on the study material below. Create {count} questions 
at {difficulty} difficulty level for grade {grade}.

Format EXACTLY as:
Q1: [Question]
A) [Option]
B) [Option]
C) [Option]
D) [Option]
Answer: [Letter]
Why: [Brief explanation]

Material:
{context}
```

### 7.3 Summary Prompt

```
System: Summarize the following study material in {style} format.
Keep it concise and focus on the most important points.
Maximum {maxPoints} points.

Material:
{context}
```

### 7.4 Explain Prompt

```
System: Explain the concept "{concept}" using the study material below.
Structure your explanation as:
1. **What it is**: Simple definition
2. **Think of it like**: An analogy or real-world comparison
3. **How it works**: Key details and mechanics
4. **Key takeaway**: One sentence summary

Material:
{context}
```

### 7.5 Worksheet Prompt

```
System: Generate {count} practice problems based on the study material.
Grade: {grade}, Subject: {subject}, Difficulty: {difficulty}
{topic ? "Focus on: $topic" : ""}

Output ONLY a JSON array:
[
  {
    "question": "...",
    "answer": "...",
    "steps": ["step 1", "step 2"],
    "difficulty": "easy|medium|hard"
  }
]

Make problems similar in style but NOT identical to the source material.
Include a mix of difficulty levels if "mixed" is specified.

Material:
{context}
```

### 7.6 Title Generator Prompt

```
System: Generate a short title (3-5 words) for this conversation based on the first message.
Output ONLY the title, nothing else.

Message: {firstMessage}
```

### 7.7 Concept Extraction Prompt

```
System: Extract educational concepts from the following text.
Output JSON:
{
  "concepts": [
    {"name": "...", "type": "term|person|formula|theorem|concept|event|place|definition", "importance": 1-5}
  ],
  "relationships": [
    {"from": "concept1", "to": "concept2", "relation": "is_part_of|relates_to|requires|..."}
  ]
}

Text:
{chunkContent}
```

---

## 8. Recommended Android Tech Stack

| Component | Flutter Original | Android Native Recommendation |
|---|---|---|
| Language | Dart | Kotlin |
| UI | Flutter Widgets | Jetpack Compose |
| Architecture | MobX + GetIt | MVVM + Hilt + StateFlow |
| Database | ObjectBox | ObjectBox (has native Android SDK) |
| Vector Search | ObjectBox HNSW | ObjectBox HNSW (same) |
| Embedding Model | TFLite via Pigeon bridge | TFLite directly via LiteRT / Google AI Edge SDK |
| Inference Model | MediaPipe via flutter_gemma | MediaPipe LLM Inference API (native) |
| PDF Extraction | Syncfusion Flutter PDF | Apache PdfBox Android / iText / Syncfusion Android |
| PDF Rendering | pdfx | Android `PdfRenderer` (built-in) |
| Image Processing | `image` package | Android Bitmap APIs / CameraX |
| Markdown | flutter_markdown_plus | Markwon (Android markdown library) |
| Math Rendering | flutter_math_fork | MathJax WebView or KaTeX |
| Graph Visualization | flutter_graph_view | GraphView Android or custom Canvas |
| Notifications | flutter_local_notifications | Android NotificationManager |
| File Picking | file_picker | Android Storage Access Framework |
| Camera | camera | CameraX |
| PDF Export | Syncfusion PDF | Apache PdfBox or iText |
| HTTP/Download | background_downloader | OkHttp + WorkManager |
| Preferences | shared_preferences | DataStore / SharedPreferences |
| Navigation | Flutter Navigator | Jetpack Navigation Compose |

---

## 9. Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Project setup, DB, basic UI shell

1. Create Android project with Jetpack Compose
2. Setup Hilt for DI
3. Integrate ObjectBox with all 6 entities (see Section 3)
4. Setup HNSW vector index on Chunk.embedding
5. Create bottom navigation with 5 tabs (empty placeholders)
6. Implement Settings screen with theme toggle
7. Implement basic Material list UI (empty state)

**Deliverable:** App launches, navigates between tabs, ObjectBox stores/retrieves data.

### Phase 2: AI Integration (Week 2-3)

**Goal:** Load and run AI models

1. Implement EmbeddingProvider:
   - Load TFLite model from assets
   - Load SentencePiece tokenizer
   - Implement `embed()`, `embedBatch()`, `countTokens()`
   - Test: embed a string, verify 768-dim output
2. Implement InferenceProvider:
   - Load MediaPipe LLM model
   - Implement streaming `generate()` with token callback
   - Implement session mutex (only one inference at a time)
   - Test: generate a response, verify streaming works
3. Implement ModelManager:
   - Load/unload models
   - Switch between Gemma ↔ Qwen
   - Track active model
4. Implement Onboarding:
   - Copy models from assets to app storage
   - Initialize models with progress UI

**Deliverable:** Models load on first launch, can embed text and generate responses.

### Phase 3: Material Processing (Week 3-4)

**Goal:** PDF/image input → chunks → embeddings → stored

1. Implement PdfInputAdapter:
   - Text extraction with paragraph grouping
   - Spaced-character detection and fix
   - Scanned PDF detection
   - Streaming per-page extraction
2. Implement VisionPdfAdapter:
   - Render PDF pages to bitmaps
   - OCR via Gemma Vision
3. Implement ImageInputAdapter + CameraInputAdapter
4. Implement TokenValidatedChunkingStrategy:
   - Paragraph accumulation → token validation → recursive split
   - Use SentencePiece tokenizer for accurate token counts
5. Implement VectorStore (ObjectBox):
   - `store()`, `storeBatch()`, `search()`, `deleteByMaterial()`
6. Implement MaterialProcessor:
   - Orchestrate: input → extract → chunk → embed → store
   - Background processing with progress reporting
   - Material deletion with cascade cleanup
7. Implement keyword extraction (rule-based, for conceptTagsJson)
8. Wire up Add Material UI + Materials list

**Deliverable:** User can add a PDF, it gets processed, chunked, embedded, and stored.

### Phase 4: RAG Chat (Week 4-5)

**Goal:** Working chat with RAG

1. Implement RagEngine:
   - Query embedding → vector search → BM25 rerank → context building → LLM generation
2. Implement ConversationManager:
   - Create/load/delete conversations
   - Message history management
   - Follow-up detection
3. Implement ChatStore/ViewModel:
   - Streaming response display
   - Material filtering
   - Image attachment + vision processing
4. Build Chat UI:
   - Message bubbles with markdown + math rendering
   - Streaming text animation
   - Source chunk references
   - Input bar with image attach
5. Build Chat History screen

**Deliverable:** User can ask questions about their materials and get RAG-powered answers.

### Phase 5: Knowledge Graph & Worksheets (Week 5-6)

**Goal:** Concept extraction, graph, worksheet generation

1. Implement LLMConceptExtractor:
   - Send chunk to LLM with concept extraction prompt
   - Parse JSON response
   - Merge/deduplicate concepts
2. Implement ConceptStore:
   - CRUD for concepts
   - Material ↔ concept relationships
   - Concept search
3. Build Knowledge Graph UI:
   - Force-directed graph layout
   - Type filter chips
   - Node tap → detail bottom sheet
4. Implement WorksheetService:
   - Config → retrieve chunks → generate problems → parse JSON
5. Implement PDF export for worksheets
6. Build Worksheet config + preview UI

**Deliverable:** Full feature parity with Flutter app.

### Phase 6: Polish & Task Queue (Week 6-7)

**Goal:** Background tasks, notifications, dev tools

1. Implement TaskQueue:
   - Priority queue for AI tasks
   - Sequential execution (one at a time)
   - Progress reporting
   - Notifications on completion/failure
2. Build TaskQueue FAB (draggable, with progress ring)
3. Implement Home dashboard (stats, quick actions, recent materials)
4. Build Dev Tools (chunk browser, storage stats)
5. Implement model download for Qwen 2.5 (settings)
6. Performance optimization:
   - Background processing with coroutines
   - Memory management for large PDFs
   - Batch embedding optimization

**Deliverable:** Production-ready native app.

---

## 10. Key Algorithms

### 10.1 Token-Validated Chunking

```
function chunk(text, metadata):
    paragraphs = split text by double newlines
    chunks = []
    buffer = ""
    
    for each paragraph:
        candidate = buffer + paragraph
        charEstimate = candidate.length
        
        if charEstimate > 4000:
            tokenCount = tokenizer.countTokens(candidate)
            if tokenCount > 1600:
                if buffer is not empty:
                    chunks.add(buffer)
                buffer = paragraph  // start new chunk
            else:
                buffer = candidate
        else:
            buffer = candidate
    
    if buffer is not empty:
        chunks.add(buffer)
    
    // Validate and split oversized chunks
    validatedChunks = []
    for each chunk:
        tokenCount = tokenizer.countTokens(chunk)
        if tokenCount > 1600:
            validatedChunks.addAll(recursiveBinarySplit(chunk, 1600))
        else:
            validatedChunks.add(chunk)
    
    // Add overlap between chunks
    return addOverlap(validatedChunks, overlapChars=200)
```

### 10.2 BM25 Scoring

```
function bm25Score(query, document, avgDocLength, docFrequencies, totalDocs):
    k1 = 1.5, b = 0.75
    score = 0
    docLength = wordCount(document)
    
    for each term in query:
        tf = termFrequency(term, document)
        df = docFrequencies[term] or 0
        idf = log((totalDocs - df + 0.5) / (df + 0.5) + 1)
        tfNorm = (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * docLength / avgDocLength))
        score += idf * tfNorm
    
    return score
```

### 10.3 Hybrid Reranking

```
function rerank(vectorResults, query, topK):
    avgDocLength = mean(result.chunk.wordCount for result in vectorResults)
    
    for each result:
        bm25 = bm25ScoreSimple(query, result.chunk.content, avgDocLength)
        result.hybridScore = 0.7 * result.vectorScore + 0.3 * normalize(bm25)
    
    sort by hybridScore descending
    return top topK results
```

### 10.4 KeyBERT-style Semantic Keyword Extraction (Experimental)

```
function extractKeywords(text, maxKeywords=10, ngramRange=(1,3), diversity=0.3):
    candidates = extractNgrams(text, ngramRange)  // filter stop words
    candidates = candidates.take(100)
    
    docEmbedding = embed(text)
    candidateEmbeddings = embedBatch(candidates)
    
    scores = [cosineSimilarity(docEmbedding, ce) for ce in candidateEmbeddings]
    
    // MMR for diversity
    selected = [argmax(scores)]
    while selected.length < maxKeywords:
        for each remaining candidate:
            relevance = (1-diversity) * scores[candidate]
            maxSimToSelected = max(cosineSim(candidate, s) for s in selected)
            mmrScore = relevance - diversity * maxSimToSelected
        selected.add(argmax(mmrScore))
    
    return selected
```

---

## 11. Error Handling

| Error Type | Description | User Action |
|---|---|---|
| ModelFailure | Model failed to load/initialize | Retry on onboarding, check storage space |
| ProcessingFailure | Material processing failed | Retry, or try vision mode for scanned PDFs |
| StorageFailure | DB operation failed | Show error, retry |
| VectorSearchFailure | Embedding search failed | Fallback to "no context found" response |
| FileFailure | File too large, not found, unsupported | Show specific error with limits |
| NetworkFailure | Download failed | Retry with exponential backoff |

---

## 12. Performance Considerations

### 12.1 Why Native?

The Flutter app has performance bottlenecks:
- **Platform channel overhead**: Every embedding/inference call crosses Dart ↔ JNI bridge
- **Memory management**: Dart GC doesn't coordinate well with native model memory
- **Threading**: Flutter's isolate model adds complexity for concurrent AI operations
- **PDF processing**: Native PDF APIs are more efficient than Flutter plugins
- **UI responsiveness**: Streaming token display can stutter in Flutter during heavy AI work

### 12.2 Native Optimization Targets

- **Embedding batching**: Use native batch API directly, no serialization overhead
- **Streaming inference**: Direct callback from MediaPipe to UI, no channel marshalling
- **Memory**: Direct control over model loading/unloading lifecycle
- **Coroutines**: Use Kotlin coroutines for clean async AI operations
- **PDF**: Android PdfRenderer is hardware-accelerated
- **Background processing**: Use WorkManager for long-running material processing

### 12.3 Memory Budget

| Component | Approximate RAM |
|---|---|
| EmbeddingGemma-300M | ~400 MB |
| Gemma 3n E2B | ~2 GB |
| Qwen 2.5 1.5B | ~1.2 GB |
| ObjectBox + indexes | ~50-200 MB |
| App + UI | ~100 MB |
| **Total (Gemma active)** | **~2.7 GB** |

Target devices: 6+ GB RAM, Android 10+

---

## 13. Testing Strategy

### Unit Tests
- Token counting accuracy (compare with SentencePiece ground truth)
- Chunking: verify token limits, overlap, boundary handling
- BM25 scoring correctness
- Keyword extraction output quality
- JSON parsing for concept extraction responses

### Integration Tests
- Full pipeline: PDF → chunks → embeddings → vector search → RAG response
- Model loading/unloading lifecycle
- Conversation persistence across app restarts
- Material deletion cascade verification

### UI Tests
- Onboarding flow completion
- Add material → processing → detail view
- Chat send → streaming response → source references
- Worksheet generation → preview → PDF export

---

## 14. File Structure (Recommended)

```
app/
├── src/main/
│   ├── kotlin/io/foxbird/edumate/lite/
│   │   ├── di/                          # Hilt modules
│   │   ├── domain/
│   │   │   ├── entities/                # Data classes
│   │   │   ├── interfaces/              # Repository/provider interfaces
│   │   │   └── usecases/                # Use case classes
│   │   ├── data/
│   │   │   ├── ai/                      # EmbeddingProvider, InferenceProvider, ModelManager
│   │   │   ├── database/                # ObjectBox setup, VectorStore impl
│   │   │   ├── input/                   # PDF, Image, Camera adapters
│   │   │   ├── chunking/                # Chunking strategies
│   │   │   └── repository/              # Repository implementations
│   │   ├── ui/
│   │   │   ├── home/                    # Home tab
│   │   │   ├── chat/                    # Chat screen + history
│   │   │   ├── materials/               # Materials list + detail + add
│   │   │   ├── knowledge/               # Knowledge graph
│   │   │   ├── worksheet/               # Worksheet config + preview
│   │   │   ├── settings/                # Settings + dev tools
│   │   │   ├── onboarding/              # Onboarding flow
│   │   │   ├── components/              # Shared composables
│   │   │   └── theme/                   # Material3 theme
│   │   └── util/                        # Logger, TokenEstimator, BM25
│   ├── assets/
│   │   └── models/                      # Bundled AI models
│   └── res/
└── build.gradle.kts
```

---

## 15. Appendix: Model Download URLs

| Model | URL | Size | Auth |
|---|---|---|---|
| EmbeddingGemma TFLite | `https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq2048_mixed-precision.tflite` | ~300 MB | Public |
| SentencePiece Tokenizer | `https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model` | ~5 MB | Public |
| Gemma 3n E2B | `https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task` | ~3.5 GB | Gated |
| Qwen 2.5 1.5B | `https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill_seq2048_kv2048.task` | ~1.6 GB | Public |
