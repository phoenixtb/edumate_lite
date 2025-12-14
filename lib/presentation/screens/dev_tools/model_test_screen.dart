import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/message.dart' as gemma_msg;
import '../../../infrastructure/ai/model_manager.dart';
import '../../../infrastructure/ai/gemma_session_manager.dart';

/// Test utility for debugging Phi-4 and Gemma model behavior
class ModelTestScreen extends StatefulWidget {
  const ModelTestScreen({super.key});

  @override
  State<ModelTestScreen> createState() => _ModelTestScreenState();
}

class _ModelTestScreenState extends State<ModelTestScreen> {
  final _promptController = TextEditingController();
  final _logController = ScrollController();
  
  // Test parameters - Phi-4 recommended: temp=0.7, topK=40, topP=0.95
  double _temperature = 0.7;
  int _topK = 40;
  double _topP = 0.95;
  int _maxTokens = 256;
  bool _useChat = true; // Use Chat API (recommended) vs Session API
  
  // State
  bool _isGenerating = false;
  String _output = '';
  List<String> _logs = [];
  DateTime? _startTime;
  int _tokenCount = 0;
  
  // Preset prompts for testing
  // NOTE: Phi-4 with MediaPipe has issues - MediaPipe adds <|endoftext|> tokens
  // that confuse Phi-4. Try very simple prompts.
  final List<Map<String, String>> _presetPrompts = [
    {'name': 'Hi', 'prompt': 'Hi'},
    {'name': '2+2', 'prompt': '2+2'},
    {'name': 'Capital', 'prompt': 'France capital?'},
    {'name': 'Hello', 'prompt': 'Hello'},
    {'name': 'Water', 'prompt': 'What is water?'},
  ];

  @override
  void initState() {
    super.initState();
    _promptController.text = 'What is the capital of France?';
    _addLog('🚀 Model Test Utility initialized');
    _loadModelInfo();
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 23);
      _logs.add('[$timestamp] $message');
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logController.hasClients) {
        _logController.animateTo(
          _logController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadModelInfo() async {
    _addLog('📋 Checking model status...');
    
    try {
      final models = await FlutterGemma.listInstalledModels();
      _addLog('📦 Installed models: ${models.join(', ')}');
      
      final hasActive = FlutterGemma.hasActiveModel();
      _addLog('🔌 Has active model: $hasActive');
      
      final activeType = ModelManager.instance.activeModel;
      _addLog('🎯 Active model type: $activeType');
      
      final currentModel = ModelManager.instance.currentModel;
      _addLog('🔧 Current model instance: ${currentModel != null ? 'loaded' : 'null'}');
    } catch (e) {
      _addLog('❌ Error loading model info: $e');
    }
  }

  Future<void> _testGeneration() async {
    if (_isGenerating) {
      _addLog('⚠️ Already generating, please wait...');
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _addLog('⚠️ Prompt is empty');
      return;
    }

    setState(() {
      _isGenerating = true;
      _output = '';
      _tokenCount = 0;
      _startTime = DateTime.now();
    });

    _addLog('─' * 50);
    _addLog('📝 Starting generation test');
    _addLog('🔧 API Mode: ${_useChat ? "CHAT (recommended)" : "SESSION"}');
    _addLog('🌡️ Temperature: $_temperature');
    _addLog('🎲 TopK: $_topK');
    _addLog('🎯 TopP: $_topP');
    _addLog('📏 Max tokens: $_maxTokens');
    _addLog('💬 Prompt: "$prompt"');

    // Acquire session lock
    _addLog('🔒 Acquiring session lock...');
    final acquired = await GemmaSessionManager.instance.acquire(
      'ModelTest',
      timeout: const Duration(seconds: 30),
    );

    if (!acquired) {
      _addLog('❌ Failed to acquire session lock');
      setState(() => _isGenerating = false);
      return;
    }
    _addLog('✅ Session lock acquired');

    InferenceChat? chat;
    InferenceModelSession? session;
    
    try {
      final model = ModelManager.instance.currentModel;
      if (model == null) {
        _addLog('❌ Model is null! Not loaded.');
        return;
      }
      _addLog('✅ Model instance obtained');

      final buffer = StringBuffer();
      int chunkCount = 0;
      String? lastToken;
      int repeatCount = 0;
      bool stopped = false;

      if (_useChat) {
        // === CHAT API (Recommended - matches official example) ===
        _addLog('🔧 Creating CHAT (temp=$_temperature, topK=$_topK, topP=$_topP)...');
        chat = await model.createChat(
          temperature: _temperature,
          topK: _topK,
          topP: _topP,
          tokenBuffer: 256,
        );
        _addLog('✅ Chat created');

        _addLog('📨 Adding query via chat.addQuery(isUser: true)...');
        await chat.addQuery(gemma_msg.Message.text(text: prompt, isUser: true));
        _addLog('✅ Query added');

        _addLog('⚡ Starting chat.generateChatResponseAsync()...');
        final responseStream = chat.generateChatResponseAsync();

        await for (final response in responseStream) {
          if (stopped) continue;
          
          String token = '';
          if (response is TextResponse) {
            token = response.token;
          }
          
          if (token.isEmpty) continue;
          
          chunkCount++;
          _tokenCount++;
          
          if (chunkCount <= 5) {
            _addLog('📥 Token $chunkCount: "${token.replaceAll('\n', '\\n')}"');
          } else if (chunkCount == 6) {
            _addLog('... (suppressing further token logs)');
          }
          
          // Detect repetition for short tokens only
          if (token == lastToken && token.isNotEmpty && token.length < 5) {
            repeatCount++;
            if (repeatCount >= 5) {
              _addLog('⚠️ Repetition detected ($repeatCount times): "$token"');
              if (repeatCount >= 10) {
                _addLog('🛑 Stopping due to excessive repetition');
                stopped = true;
                try { await chat.stopGeneration(); } catch (_) {}
                continue;
              }
            }
          } else {
            if (repeatCount >= 3) {
              _addLog('📊 Previous token repeated $repeatCount times');
            }
            repeatCount = 0;
            lastToken = token;
          }
          
          buffer.write(token);
          setState(() { _output = buffer.toString(); });
          
          if (buffer.length > _maxTokens * 4 || _tokenCount >= _maxTokens) {
            _addLog('🛑 Limit reached');
            stopped = true;
            try { await chat.stopGeneration(); } catch (_) {}
          }
        }
      } else {
        // === SESSION API (Low-level) ===
        _addLog('🔧 Creating SESSION (temp=$_temperature, topK=$_topK)...');
        session = await model.createSession(
          temperature: _temperature,
          topK: _topK,
        );
        _addLog('✅ Session created');

        _addLog('📨 Adding query via session.addQueryChunk(isUser: true)...');
        await session.addQueryChunk(
          gemma_msg.Message.text(text: prompt, isUser: true),
        );
        _addLog('✅ Query added');

        _addLog('⚡ Starting session.getResponseAsync()...');
        final responseStream = session.getResponseAsync();
        
        await for (final chunk in responseStream) {
          if (stopped) continue;
          
          chunkCount++;
          _tokenCount++;
          
          if (chunkCount <= 5) {
            _addLog('📥 Chunk $chunkCount: "${chunk.replaceAll('\n', '\\n')}"');
          } else if (chunkCount == 6) {
            _addLog('... (suppressing further chunk logs)');
          }
          
          if (chunk == lastToken && chunk.isNotEmpty && chunk.length < 5) {
            repeatCount++;
            if (repeatCount >= 10) {
              _addLog('🛑 Stopping due to excessive repetition');
              stopped = true;
              continue;
            }
          } else {
            repeatCount = 0;
            lastToken = chunk;
          }
          
          buffer.write(chunk);
          setState(() { _output = buffer.toString(); });
          
          if (buffer.length > _maxTokens * 4 || _tokenCount >= _maxTokens) {
            stopped = true;
          }
        }
      }

      _addLog('📊 Stream fully drained');
      final duration = DateTime.now().difference(_startTime!);
      _addLog('✅ Generation complete');
      _addLog('📊 Total tokens: $chunkCount');
      _addLog('📊 Output length: ${buffer.length} chars');
      _addLog('⏱️ Duration: ${duration.inMilliseconds}ms');
      if (duration.inMilliseconds > 0) {
        _addLog('🚀 Speed: ${(chunkCount / (duration.inMilliseconds / 1000)).toStringAsFixed(1)} tok/s');
      }
      
    } catch (e, stack) {
      _addLog('❌ Generation error: $e');
      _addLog('📚 Stack: ${stack.toString().split('\n').take(3).join('\n')}');
    } finally {
      _addLog('🔒 Closing (with delay)...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Note: InferenceChat doesn't require explicit close - session is managed internally
      if (chat != null) {
        _addLog('✅ Chat complete (no explicit close needed)');
      }
      
      if (session != null) {
        try {
          await session.close();
          _addLog('✅ Session closed');
        } catch (e) {
          _addLog('⚠️ Session close error: $e');
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      GemmaSessionManager.instance.release('ModelTest');
      _addLog('🔓 Session lock released');
      
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _switchModel(ActiveModelType targetType) async {
    _addLog('🔄 Switching to ${targetType.name}...');
    
    setState(() => _isGenerating = true);
    
    try {
      if (targetType == ActiveModelType.gemma) {
        final success = await ModelManager.instance.switchToGemma();
        _addLog(success ? '✅ Switched to Gemma' : '❌ Failed to switch to Gemma');
      } else if (targetType == ActiveModelType.phi4 || targetType == ActiveModelType.deepseek) {
        final success = await ModelManager.instance.switchToDeepseek();
        _addLog(success ? '✅ Switched to DeepSeek' : '❌ Failed to switch to DeepSeek');
      }
      
      await _loadModelInfo();
    } catch (e) {
      _addLog('❌ Switch error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _output = '';
    });
    _addLog('🗑️ Logs cleared');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeModel = ModelManager.instance.activeModel;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Test Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          // Model Switch Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Text('Active: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Chip(
                  label: Text(
                    activeModel.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: (activeModel == ActiveModelType.phi4 || activeModel == ActiveModelType.deepseek)
                      ? Colors.orange.shade100
                      : activeModel == ActiveModelType.gemma 
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isGenerating ? null : () => _switchModel(ActiveModelType.gemma),
                  child: const Text('Gemma'),
                ),
                TextButton(
                  onPressed: _isGenerating ? null : () => _switchModel(ActiveModelType.deepseek),
                  child: const Text('DeepSeek'),
                ),
              ],
            ),
          ),
          
          // API Mode Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Text('API: '),
                ChoiceChip(
                  label: const Text('Chat'),
                  selected: _useChat,
                  onSelected: (v) => setState(() => _useChat = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Session'),
                  selected: !_useChat,
                  onSelected: (v) => setState(() => _useChat = false),
                ),
                const Spacer(),
                Text('Temp: ${_temperature.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _temperature,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: (v) => setState(() => _temperature = v),
                  ),
                ),
              ],
            ),
          ),
          
          // Preset prompts
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _presetPrompts.length,
              itemBuilder: (context, index) {
                final preset = _presetPrompts[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(preset['name']!, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _promptController.text = preset['prompt']!,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Prompt input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _promptController,
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Test Prompt',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, color: Colors.green),
                  onPressed: _isGenerating ? null : _testGeneration,
                ),
              ),
            ),
          ),
          
          // Output
          if (_output.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 100),
              width: double.infinity,
              child: SingleChildScrollView(
                child: SelectableText(
                  _output,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          
          const Divider(height: 1),
          
          // Logs
          Expanded(
            child: Container(
              color: Colors.black87,
              child: ListView.builder(
                controller: _logController,
                padding: const EdgeInsets.all(6),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white70;
                  if (log.contains('❌') || log.contains('error')) {
                    textColor = Colors.red.shade300;
                  } else if (log.contains('⚠️')) {
                    textColor = Colors.orange.shade300;
                  } else if (log.contains('✅')) {
                    textColor = Colors.green.shade300;
                  }
                  
                  return Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: textColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _logController.dispose();
    super.dispose();
  }
}
