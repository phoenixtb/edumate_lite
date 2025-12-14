import 'dart:typed_data';
import 'package:mobx/mobx.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/message.dart';
import '../domain/services/rag_engine.dart';
import '../domain/services/conversation_manager.dart';
import '../domain/services/vision_service.dart';
import '../domain/services/inference_router.dart';
import '../core/prompts/prompt_templates.dart';
import '../config/service_locator.dart';

part 'chat_store.g.dart';

class ChatStore = ChatStoreBase with _$ChatStore;

abstract class ChatStoreBase with Store {
  final RagEngine _ragEngine = getIt<RagEngine>();
  final ConversationManager _conversationManager = getIt<ConversationManager>();
  final InferenceRouter _inferenceRouter = getIt<InferenceRouter>();

  @observable
  Conversation? currentConversation;

  @observable
  ObservableList<Message> messages = ObservableList<Message>();

  @observable
  ObservableList<Conversation> conversations = ObservableList<Conversation>();

  @observable
  bool isLoading = false;

  @observable
  bool isLoadingConversations = false;

  @observable
  String? error;

  @action
  void clearError() {
    error = null;
  }

  @observable
  String currentResponse = '';

  @observable
  List<int>? selectedMaterialIds;

  @action
  Future<void> startNewConversation(String title, {int? materialId}) async {
    isLoading = true;
    error = null;

    final result = await _conversationManager.createConversation(
      title: title,
      materialId: materialId,
    );

    result.fold(
      (failure) {
        error = failure.message;
        isLoading = false;
      },
      (conversation) {
        currentConversation = conversation;
        messages.clear();
        isLoading = false;
      },
    );
  }

  /// Prepare for a new chat without creating DB entry (lazy creation)
  /// The conversation will be created when the first message is sent
  @action
  void prepareNewChat() {
    currentConversation = null;
    messages.clear();
    currentResponse = '';
    error = null;
  }

  @action
  Future<void> loadConversation(int conversationId) async {
    isLoading = true;
    error = null;

    final convResult = await _conversationManager.getConversation(conversationId);
    final historyResult = await _conversationManager.getContextHistory(conversationId);

    convResult.fold(
      (failure) {
        error = failure.message;
        isLoading = false;
      },
      (conversation) {
        currentConversation = conversation;
        
        historyResult.fold(
          (failure) => error = failure.message,
          (history) => messages = ObservableList.of(history),
        );
        
        isLoading = false;
      },
    );
  }

  @action
  Future<void> sendMessage(String content) async {
    isLoading = true;
    error = null;
    currentResponse = '';

    // Lazy creation: create conversation on first message
    if (currentConversation == null) {
      final result = await _conversationManager.createConversation(
        title: 'New Chat', // Will be updated after title generation
        materialId: null,
      );
      
      final created = result.fold(
        (failure) {
          error = failure.message;
          isLoading = false;
          return false;
        },
        (conversation) {
          currentConversation = conversation;
          return true;
        },
      );
      
      if (!created) return;
    }

    // Check if this is the first message (for title generation)
    final isFirstMessage = messages.isEmpty;

    // Add user message
    final userMsgResult = await _conversationManager.addMessage(
      currentConversation!.id,
      role: 'user',
      content: content,
    );

    userMsgResult.fold(
      (failure) {
        error = failure.message;
        isLoading = false;
        return;
      },
      (userMessage) {
        messages.add(userMessage);
      },
    );

    // Get RAG response first
    final ragResult = await _ragEngine.answer(
      content,
      materialIds: selectedMaterialIds,
      conversationHistory: messages.toList(),
    );

    await ragResult.fold(
      (failure) async {
        error = failure.message;
        isLoading = false;
      },
      (responseStream) async {
        final buffer = StringBuffer();
        List<int>? retrievedChunkIds;
        double? confidence;

        await for (final response in responseStream) {
          if (!response.isComplete) {
            buffer.write(response.content);
            currentResponse = buffer.toString();
          }

          if (response.retrievedChunks != null) {
            retrievedChunkIds = response.retrievedChunks!
                .map((sc) => sc.chunk.id)
                .toList();
          }
          confidence = response.confidenceScore;

          if (response.isComplete) {
            // Post-process to remove hallucinated "not available" suffix
            final cleanedContent = _cleanResponse(buffer.toString());
            
            // Save assistant message
            final assistantMsgResult = await _conversationManager.addMessage(
              currentConversation!.id,
              role: 'assistant',
              content: cleanedContent,
              retrievedChunkIds: retrievedChunkIds,
              confidenceScore: confidence,
            );

            assistantMsgResult.fold(
              (failure) => error = failure.message,
              (assistantMessage) {
                messages.add(assistantMessage);
                currentResponse = '';
              },
            );
          }
        }

        isLoading = false;
        
        // Generate title AFTER response is complete with a delay
        // to ensure the previous session is fully closed
        if (isFirstMessage) {
          Future.delayed(const Duration(seconds: 2), () {
            _generateTitle(content);
          });
        }
      },
    );
  }

  /// Send a message with an attached image
  @action
  Future<void> sendImageMessage(Uint8List imageBytes, String question) async {
    isLoading = true;
    error = null;
    currentResponse = '';

    // Lazy creation: create conversation on first message
    if (currentConversation == null) {
      final result = await _conversationManager.createConversation(
        title: 'New Chat',
        materialId: null,
      );

      final created = result.fold(
        (failure) {
          error = failure.message;
          isLoading = false;
          return false;
        },
        (conversation) {
          currentConversation = conversation;
          return true;
        },
      );

      if (!created) return;
    }

    final isFirstMessage = messages.isEmpty;

    // Add user message with image indicator
    final userMsgResult = await _conversationManager.addMessage(
      currentConversation!.id,
      role: 'user',
      content: '📷 [Image attached]\n$question',
    );

    userMsgResult.fold(
      (failure) {
        error = failure.message;
        isLoading = false;
        return;
      },
      (userMessage) {
        messages.add(userMessage);
      },
    );

    // Use VisionService to answer about the image
    try {
      final buffer = StringBuffer();

      await for (final chunk in VisionService.instance.answerQuestion(
        imageBytes,
        question,
      )) {
        buffer.write(chunk);
        currentResponse = buffer.toString();
      }

      final cleanedContent = _cleanResponse(buffer.toString());

      // Save assistant message
      final assistantMsgResult = await _conversationManager.addMessage(
        currentConversation!.id,
        role: 'assistant',
        content: cleanedContent,
      );

      assistantMsgResult.fold(
        (failure) => error = failure.message,
        (assistantMessage) {
          messages.add(assistantMessage);
          currentResponse = '';
        },
      );
      
      // Generate title AFTER response is complete
      if (isFirstMessage) {
        _generateTitle(question);
      }
    } catch (e) {
      error = 'Failed to process image: $e';
    }

    isLoading = false;
  }

  @action
  void clearConversation() {
    currentConversation = null;
    messages.clear();
    currentResponse = '';
    error = null;
  }

  @action
  void setSelectedMaterials(List<int>? materialIds) {
    selectedMaterialIds = materialIds;
  }

  @action
  Future<void> loadConversations() async {
    isLoadingConversations = true;
    error = null;

    final result = await _conversationManager.getAllConversations();

    result.fold(
      (failure) {
        error = failure.message;
        isLoadingConversations = false;
      },
      (convList) {
        conversations = ObservableList.of(convList);
        isLoadingConversations = false;
      },
    );
  }

  @action
  Future<void> deleteConversation(int conversationId) async {
    final result = await _conversationManager.deleteConversation(conversationId);

    result.fold(
      (failure) => error = failure.message,
      (_) {
        conversations.removeWhere((c) => c.id == conversationId);
        if (currentConversation?.id == conversationId) {
          clearConversation();
        }
      },
    );
  }

  /// Regenerate the last assistant response
  @action
  Future<void> regenerateLastResponse() async {
    if (currentConversation == null || messages.length < 2) {
      error = 'Cannot regenerate - no previous response';
      return;
    }

    // Find the last user message
    String? lastUserContent;
    int lastAssistantIndex = -1;

    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'assistant' && lastAssistantIndex == -1) {
        lastAssistantIndex = i;
      }
      if (messages[i].role == 'user') {
        lastUserContent = messages[i].content;
        break;
      }
    }

    if (lastUserContent == null || lastAssistantIndex == -1) {
      error = 'Cannot regenerate - no previous message pair';
      return;
    }

    // Delete the last assistant message from DB and list
    final lastAssistantMsg = messages[lastAssistantIndex];
    await _conversationManager.deleteMessage(lastAssistantMsg.id);
    messages.removeAt(lastAssistantIndex);

    // Re-generate response
    isLoading = true;
    error = null;
    currentResponse = '';

    final ragResult = await _ragEngine.answer(
      lastUserContent,
      materialIds: selectedMaterialIds,
      conversationHistory: messages.toList(),
    );

    await ragResult.fold(
      (failure) async {
        error = failure.message;
        isLoading = false;
      },
      (responseStream) async {
        final buffer = StringBuffer();
        List<int>? retrievedChunkIds;
        double? confidence;

        await for (final response in responseStream) {
          if (!response.isComplete) {
            buffer.write(response.content);
            currentResponse = buffer.toString();
          }

          if (response.retrievedChunks != null) {
            retrievedChunkIds = response.retrievedChunks!
                .map((sc) => sc.chunk.id)
                .toList();
          }
          confidence = response.confidenceScore;

          if (response.isComplete) {
            final assistantMsgResult = await _conversationManager.addMessage(
              currentConversation!.id,
              role: 'assistant',
              content: buffer.toString(),
              retrievedChunkIds: retrievedChunkIds,
              confidenceScore: confidence,
            );

            assistantMsgResult.fold(
              (failure) => error = failure.message,
              (assistantMessage) {
                messages.add(assistantMessage);
                currentResponse = '';
              },
            );
          }
        }

        isLoading = false;
      },
    );
  }

  /// Generate a short title from the first message using LLM
  Future<void> _generateTitle(String firstMessage) async {
    if (currentConversation == null || !_inferenceRouter.isReady) return;
    
    // Skip if title is already set (not "New Chat")
    if (currentConversation!.title != 'New Chat') return;
    
    try {
      final titleTemplate = PromptFactory.get(PromptType.title);
      final titleBuffer = StringBuffer();
      
      await for (final chunk in _inferenceRouter.generate(
        systemPrompt: titleTemplate.systemPrompt,
        context: '',
        query: titleTemplate.buildPrompt({'message': firstMessage}),
      )) {
        titleBuffer.write(chunk);
      }
      
      var title = titleBuffer.toString().trim();
      
      // Clean up the title
      title = title.replaceAll('"', '').replaceAll("'", '');
      if (title.length > 40) {
        title = '${title.substring(0, 37)}...';
      }
      
      // Update conversation title
      if (title.isNotEmpty && currentConversation != null) {
        final result = await _conversationManager.updateTitle(
          currentConversation!.id,
          title,
        );
        
        result.fold(
          (_) {},
          (updated) {
            currentConversation = updated;
          },
        );
      }
    } catch (e) {
      // Silently fail - title generation is not critical
    }
  }

  /// Clean up model response by removing hallucinated suffixes
  /// The model sometimes appends "This information is not available" even after answering
  String _cleanResponse(String response) {
    // Patterns that indicate hallucinated "not available" suffix after actual content
    final hallucinationPatterns = [
      RegExp(r'\s*This information is not (available|in your|found).*$', caseSensitive: false),
      RegExp(r"\s*I (could not|couldn't|cannot|can't) find.*materials?\.?\s*$", caseSensitive: false),
      RegExp(r'\s*The (information|answer|topic).*not (available|covered|found).*$', caseSensitive: false),
    ];

    var cleaned = response.trim();
    
    // Only clean if there's substantial content before the hallucination
    // (at least 100 chars suggests the model did answer something)
    if (cleaned.length > 150) {
      for (final pattern in hallucinationPatterns) {
        cleaned = cleaned.replaceAll(pattern, '').trim();
      }
    }
    
    return cleaned;
  }
}

