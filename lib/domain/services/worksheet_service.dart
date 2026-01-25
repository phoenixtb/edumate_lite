import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../interfaces/embedding_provider.dart';
import '../interfaces/vector_store.dart';
import '../entities/worksheet.dart';
import '../../core/errors/failures.dart';
import '../../core/prompts/prompt_templates.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/token_estimator.dart';
import '../../infrastructure/ai/model_manager.dart';
import 'inference_router.dart';

/// Service for generating practice worksheets from materials
class WorksheetService {
  final EmbeddingProvider embeddingProvider;
  final VectorStore vectorStore;
  final InferenceRouter inferenceRouter;

  /// Max tokens for context window
  final int maxContextTokens;

  WorksheetService({
    required this.embeddingProvider,
    required this.vectorStore,
    required this.inferenceRouter,
    this.maxContextTokens = 1500,
  });

  /// Generate a worksheet from materials
  ///
  /// Returns Either Failure or Worksheet
  Future<Either<Failure, Worksheet>> generateWorksheet(
    WorksheetConfig config, {
    void Function(double progress, String message)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Preparing...');

      // Validate
      if (config.materialIds.isEmpty) {
        return Left(ProcessingFailure('No materials selected'));
      }

      if (ModelManager.instance.activeModel == ActiveModelType.none) {
        return Left(ModelFailure('Inference model not loaded'));
      }

      onProgress?.call(0.1, 'Retrieving content...');

      // Get relevant chunks from materials
      final allChunks = <ScoredChunk>[];
      for (final materialId in config.materialIds) {
        final chunks = await vectorStore.getByMaterial(materialId);
        // Prioritize equations and examples for worksheet generation
        final prioritized = chunks.where((c) =>
            c.chunkType == 'equation' ||
            c.chunkType == 'example' ||
            c.chunkType == 'definition');
        final others = chunks.where((c) =>
            c.chunkType != 'equation' &&
            c.chunkType != 'example' &&
            c.chunkType != 'definition');

        allChunks.addAll(prioritized.map((c) => ScoredChunk(chunk: c, score: 1.0)));
        allChunks.addAll(others.map((c) => ScoredChunk(chunk: c, score: 0.8)));
      }

      if (allChunks.isEmpty) {
        return Left(ProcessingFailure('No content found in selected materials'));
      }

      // Sort by score (prioritized first)
      allChunks.sort((a, b) => b.score.compareTo(a.score));

      onProgress?.call(0.2, 'Building context...');

      // Build context from chunks (within token limit)
      final context = _buildContext(allChunks);

      onProgress?.call(0.3, 'Generating problems...');

      // Generate worksheet using LLM
      final worksheetTemplate = PromptFactory.get(PromptType.worksheet);
      final formattedContext = worksheetTemplate.formatContext(context);
      final prompt = worksheetTemplate.buildPrompt({
        'problemCount': config.problemCount,
        'gradeLevel': config.gradeLevel,
        'subject': config.subject,
        'difficulty': config.difficulty,
        'topic': config.topic ?? '',
      });

      // Collect streamed response
      final responseBuffer = StringBuffer();
      final responseStream = inferenceRouter.generate(
        systemPrompt: worksheetTemplate.systemPrompt,
        context: formattedContext,
        query: prompt,
      );

      await for (final chunk in responseStream) {
        responseBuffer.write(chunk);
        // Update progress based on expected response length
        final estimated = config.problemCount * 150; // ~150 chars per problem
        final progress = 0.3 + (responseBuffer.length / estimated).clamp(0.0, 0.6);
        onProgress?.call(progress, 'Generating problems...');
      }

      onProgress?.call(0.9, 'Parsing response...');

      final responseText = responseBuffer.toString().trim();
      AppLogger.debug('📝 [WORKSHEET] Raw response: ${responseText.substring(0, responseText.length.clamp(0, 200))}...');

      // Parse JSON response
      final problems = _parseProblems(responseText);

      if (problems.isEmpty) {
        return Left(ProcessingFailure(
            'Failed to generate problems. Please try again.'));
      }

      onProgress?.call(1.0, 'Done!');

      // Build worksheet
      final worksheet = Worksheet(
        title: _generateTitle(config),
        problems: problems,
        gradeLevel: config.gradeLevel,
        subject: config.subject,
        topic: config.topic,
        difficulty: config.difficulty,
        materialIds: config.materialIds,
      );

      AppLogger.info(
          '✅ [WORKSHEET] Generated ${problems.length} problems for "${worksheet.title}"');

      return Right(worksheet);
    } catch (e, stackTrace) {
      AppLogger.error('❌ [WORKSHEET] Generation failed', e, stackTrace);
      return Left(ProcessingFailure('Worksheet generation failed: $e'));
    }
  }

  /// Build context string from chunks
  String _buildContext(List<ScoredChunk> chunks) {
    final buffer = StringBuffer();
    var currentTokens = 0;

    for (final scoredChunk in chunks) {
      final chunk = scoredChunk.chunk;
      final chunkTokens = TokenEstimator.estimate(chunk.content);

      if (currentTokens + chunkTokens > maxContextTokens) {
        break;
      }

      // Label chunk type for context
      buffer.writeln('[${chunk.chunkType.toUpperCase()}]');
      buffer.writeln(chunk.content);
      buffer.writeln();

      currentTokens += chunkTokens;
    }

    return buffer.toString();
  }

  /// Parse LLM response into Problem objects
  List<Problem> _parseProblems(String response) {
    final problems = <Problem>[];

    // Try JSON parsing first
    try {
      // Find JSON array in response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final parsed = jsonDecode(jsonStr) as List<dynamic>;

        for (final item in parsed) {
          if (item is Map<String, dynamic>) {
            problems.add(Problem.fromJson(item));
          }
        }

        if (problems.isNotEmpty) {
          AppLogger.debug(
              '✅ [WORKSHEET] Parsed ${problems.length} problems from JSON');
          return problems;
        }
      }
    } catch (e) {
      AppLogger.warning('⚠️ [WORKSHEET] JSON parsing failed: $e');
    }

    // Fallback: regex extraction
    return _parseProblemsWithRegex(response);
  }

  /// Fallback parser using regex patterns
  List<Problem> _parseProblemsWithRegex(String response) {
    final problems = <Problem>[];

    // Pattern: numbered problems like "1." or "Q1:" or "Problem 1:"
    final problemPattern = RegExp(
      r'(?:^|\n)(?:Q?(?:uestion)?\.?\s*)?(\d+)[.):]\s*(.+?)(?=(?:\n(?:Q?(?:uestion)?\.?\s*)?\d+[.):])|\Z)',
      multiLine: true,
      dotAll: true,
    );

    final matches = problemPattern.allMatches(response);

    for (final match in matches) {
      final content = match.group(2)?.trim() ?? '';
      if (content.isEmpty) continue;

      // Try to split question and answer
      String question = content;
      String answer = '';
      final steps = <String>[];

      // Look for answer markers
      final answerMatch = RegExp(
        r'(?:Answer|Solution|A:)\s*[:\-]?\s*(.+?)(?:\n|$)',
        caseSensitive: false,
      ).firstMatch(content);

      if (answerMatch != null) {
        answer = answerMatch.group(1)?.trim() ?? '';
        question = content.substring(0, answerMatch.start).trim();
      }

      // Look for steps
      final stepsMatch = RegExp(
        r'(?:Steps?|Solution):?\s*((?:\d+\..+?\n?)+)',
        caseSensitive: false,
      ).firstMatch(content);

      if (stepsMatch != null) {
        final stepsText = stepsMatch.group(1) ?? '';
        steps.addAll(stepsText
            .split(RegExp(r'\d+\.'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty));
      }

      problems.add(Problem(
        question: question,
        answer: answer,
        steps: steps,
        difficulty: 'medium',
      ));
    }

    AppLogger.debug(
        '📝 [WORKSHEET] Extracted ${problems.length} problems via regex');
    return problems;
  }

  /// Generate worksheet title
  String _generateTitle(WorksheetConfig config) {
    final subjectCapitalized =
        config.subject[0].toUpperCase() + config.subject.substring(1);
    final topic = config.topic?.isNotEmpty == true ? ' - ${config.topic}' : '';
    return 'Grade ${config.gradeLevel} $subjectCapitalized Worksheet$topic';
  }
}
