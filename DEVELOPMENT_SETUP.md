# EduMate Lite - Developer Setup Instructions

**Last Updated:** January 14, 2026

## 🎯 IMPORTANT: Bundled Model Approach

We use **bundled models** to avoid security risks:

### ❌ Why NOT Download-on-Demand?
```
User installs app with embedded token
  → App decompiled by attacker
  → Token extracted from binary
  → Token misused for unlimited HuggingFace downloads
  → Your token gets rate-limited/banned
  → App breaks for all users
```

### ✅ Why Bundled Models?
```
Developer downloads models ONCE (with token)
  → Models packaged in assets/
  → Token NEVER in production app
  → Impossible to extract non-existent token
  → 100% offline, 100% secure
  → Perfect for privacy-first kids app
```

## 📊 Current Model Status

| Model | Size | Status | Notes |
|-------|------|--------|-------|
| Gemma 3n E2B | 3.5GB | ✅ Active | Primary inference, works on all devices |
| EmbeddingGemma 300M | 300MB | ✅ Active | Semantic search |
| Qwen 2.5 | ~1.5GB | ⚠️ Experimental | Hardware issues on MediaTek/Mali GPUs |

---

## 📋 One-Time Setup (For Developers)

### Step 1: Get HuggingFace Token

1. **Create account:** https://huggingface.co/join
2. **Create token:** https://huggingface.co/settings/tokens
   - Token type: Read
   - Name: "edumate_model_download"
3. **Request model access (instant approval):**
   - https://huggingface.co/google/embeddinggemma-300m → Click "Request Access"
   - https://huggingface.co/google/gemma-3n-E2B-it-litert-preview → Click "Request Access"

### Step 2: Download Models

```bash
cd /Users/titasbiswas/ai/pet/on_device/edumate_lite

# Set token temporarily
export HUGGINGFACE_TOKEN='hf_YOUR_TOKEN_HERE'

# Download models (one time only, ~10-30 min)
./scripts/download_models.sh
```

**This will download to `assets/models/`:**
- embeddinggemma-300M_seq512_mixed-precision.tflite (300MB)
- embeddinggemma_tokenizer.model (5MB)  
- gemma-3n-E2B-it-int4.task (3.5GB)

**Total: 3.8GB**

### Step 3: Verify

```bash
ls -lh assets/models/

# You should see:
# -rw-r--r--  embeddinggemma-300M_seq512_mixed-precision.tflite (~300M)
# -rw-r--r--  embeddinggemma_tokenizer.model (~5M)
# -rw-r--r--  gemma-3n-E2B-it-int4.task (~3.5G)
```

### Step 4: Run App

```bash
# No token needed! Models are bundled
flutter run
```

---

## 🔄 For Other Developers on Your Team

Once YOU'VE downloaded models and committed pubspec.yaml:

```bash
git clone <repo>
cd edumate_lite

# Download models (same script, same token)
export HUGGINGFACE_TOKEN='hf_token'
./scripts/download_models.sh

# Run
flutter run
```

**OR** share the downloaded model files directly (not via git - too large):
- Google Drive / Dropbox
- Place in `assets/models/`
- Run app

---

## 📦 Production Build

```bash
# Android APK (will be ~4GB)
flutter build apk --release

# Android App Bundle (recommended for Play Store)
# Supports on-demand delivery of models by architecture
flutter build appbundle --release

# iOS
flutter build ios --release
```

**App size:** ~4GB total
- APK/IPA: 4GB
- Play Store can use Android App Bundle to split by architecture

---

## 🔐 Security Checklist

- ✅ Models in `assets/models/` (gitignored)
- ✅ `config.json` in gitignore (if exists)
- ✅ No token in source code
- ✅ No token in environment variables (production)
- ✅ Token only used locally for ONE-TIME download
- ✅ Production app uses `.fromAsset()` not `.fromNetwork()`
- ✅ Users can't extract token (doesn't exist in app)

---

## 🧪 Testing

```bash
# All tests (no models needed for unit tests)
flutter test

# Run specific suite
flutter test test/domain/services/rag_engine_test.dart

# Analyze code
flutter analyze
```

**Current: 40 tests passing, 0 errors**

---

## 📱 Testing on Real Device

### First Launch Flow:
1. Install app (~4GB download from store/build)
2. Open app → Shows "Load AI Models" screen
3. Tap "Load Models" → Progress bars
4. Wait ~30 seconds (loading from bundled assets)
5. "All Set!" → Tap "Start Using EduMate"
6. Home screen ready

### Add Material:
1. Tap "Add Material"
2. Choose PDF (try a small textbook - 5-10 pages)
3. Fill in title, subject (math/science/etc), grade (5-10)
4. Tap "Process"
5. Watch progress:
   - Extracting: Syncfusion reads PDF
   - Chunking: Splits into chunks (see console for count)
   - Embedding: AI generates vectors (this takes time!)
   - Storing: Saves to ObjectBox
6. Status changes to "Completed" ✅

### Chat:
1. Tap "Ask Question"
2. Type: "What is this material about?"
3. Watch:
   - AI generates query embedding
   - Vector search finds chunks (check confidence)
   - Gemma 3 Nano streams response word-by-word
4. Try follow-up: "Can you explain more about [topic]?"
5. Filter by material if multiple uploaded

---

## 🎓 Model Details

### EmbeddingGemma-300M
- **Purpose:** Convert text to 768-dimensional vectors
- **Size:** 300MB
- **Usage:** Query embeddings + chunk embeddings
- **Speed:** ~1 sec per embedding on modern phone
- **Loading:** `fromAsset()` - bundled in app

### Gemma 3n E2B (Primary)
- **Purpose:** Generate answers + Vision OCR
- **Size:** 3.5GB (int4 quantized)
- **Capabilities:**
  - Text generation (Q&A, explanations)
  - Vision (OCR from images/camera)
  - Multimodal understanding
- **Speed:** ~2-3 tokens/sec on modern phone
- **Loading:** `fromAsset()` - bundled in app
- **Status:** ✅ Works on all tested devices

### Qwen 2.5 (Experimental - Disabled)
- **Purpose:** Enhanced text generation
- **Size:** ~1.5GB
- **Status:** ⚠️ Disabled in Settings UI
- **Issue:** TFLite `GATHER_ND` op fails on MediaTek/Mali GPUs
- **Loading:** `fromBundled()` - after network download
- **Re-enable:** Update `settings_screen.dart` when hardware support improves

---

## 🚨 Common Issues

### "Failed to load model"
- Ensure all 3 files are in `assets/models/`
- Check file sizes match expected
- Try `flutter clean && flutter run`

### "Asset not found"
- Run download script again
- Verify pubspec.yaml has `assets/models/`

### Out of Memory
- Device needs 6GB+ RAM for Gemma 3n
- Try on higher-end device
- Consider using smaller model in future (Gemma 3 270M)

### Slow Embedding
- First embedding takes longer (model init)
- Subsequent ones are faster
- Expected: 20 chunks = ~40 seconds

### Qwen/DeepSeek Not Working
- **Known issue:** Hardware incompatibility on MediaTek/Mali GPUs
- **Error:** `GATHER_ND` TFLite operation failure
- **Solution:** Use Gemma 3n (default, works everywhere)
- **Status:** Qwen disabled in Settings UI with "Experimental - Coming Soon"

### Empty Response / Generation Failed
- Check device RAM (6GB+ required)
- Try restarting app (model session may be stale)
- If using Qwen, switch to Gemma 3n in Settings

---

## 📈 Next Development Steps

1. ✅ **MVP Complete** - Gemma 3n working on all devices
2. ✅ **Qwen Integration** - Attempted, disabled due to hardware issues
3. **Test with real content** - Try actual textbooks
4. **Tune parameters:**
   - Chunking size (currently 350 tokens)
   - Similarity threshold (currently 0.5)
   - Top-K retrieval (currently 5)
5. **Add quiz UI** - Quiz generation backend is ready
6. **Subject enhancers** - Math/Science specific chunking
7. **Polish UI** - Animations, transitions
8. **App Store preparation** - Screenshots, description

### Qwen Re-enablement Checklist
- [ ] Test on Qualcomm Snapdragon 8 Gen 2+ devices
- [ ] Test on Samsung Exynos devices
- [ ] Monitor flutter_gemma releases for MediaPipe fixes
- [ ] Re-enable in `settings_screen.dart` when compatible

---

## 💡 Tips

- **Use small PDFs initially** (5-10 pages) to test faster
- **Watch logs** for chunking output (chunk count, types detected)
- **Try different subjects** (math vs history - different chunk patterns)
- **Test follow-up questions** (conversation context works!)
- **Check confidence scores** (< 0.7 shows warning)

---

**Ready to build a production-quality offline AI education app!** 🚀

No security risks, no token exposure, works perfectly offline, ideal for kids.

---

## 📝 Debugging Reference

### Key Logs to Watch
```bash
# Filter for model loading
adb logcat | grep -E "(Gemma|Qwen|flutter_gemma|TFLite)"

# Filter for inference
adb logcat | grep -E "(generateResponse|InferenceRouter)"
```

### Important Files for Debugging
- `lib/infrastructure/ai/inference_router.dart` - Model routing
- `lib/infrastructure/ai/model_manager.dart` - Model lifecycle
- `lib/stores/app_store.dart` - Model state flags
- `lib/presentation/screens/settings/settings_screen.dart` - UI toggles
