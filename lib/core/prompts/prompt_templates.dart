/// Prompt Templates for LLM interactions
/// Centralized prompt management for consistent, high-quality outputs

/// Base class for all prompt templates
abstract class PromptTemplate {
  /// System prompt that sets the AI's behavior and constraints
  String get systemPrompt;

  /// Build the user prompt with given parameters
  String buildPrompt(Map<String, dynamic> params);

  /// Format context from source materials
  String formatContext(String rawContext) {
    return '''
<source_material>
$rawContext
</source_material>
''';
  }
}

/// Prompt template for answering questions (Q&A)
/// Optimized for small models with formatting focus
class QAPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You are EduMate, a friendly tutor for students grades 5-10.

RULES:
• Answer using ONLY the provided material
• Use simple, clear language
• Format responses for easy reading

FORMAT YOUR RESPONSE:
• Start with a brief intro (1-2 sentences)
• Use **bold** for key terms
• Use bullet points (•) for lists
• Use numbered steps for processes
• Keep paragraphs short (2-3 sentences)
• End with a key takeaway''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final query = params['query'] as String? ?? '';
    return '''Question: $query

Answer clearly with good formatting. Use paragraphs, bullets, and bold for readability.''';
  }
}

/// Prompt template for generating quizzes
/// Optimized for small models
class QuizPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You create educational quizzes for students grades 5-10.

FORMAT each question as:
Q[n]: [Question]
A) [Option] B) [Option] C) [Option] D) [Option]
Answer: [Letter]
Why: [Brief explanation]''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final questionCount = params['questionCount'] as int? ?? 5;
    final topic = params['topic'] as String?;

    final topicLine = topic != null ? 'Focus on: $topic\n' : '';

    return '''${topicLine}Create $questionCount multiple-choice questions from the material above.''';
  }
}

/// Prompt template for summarization
/// Optimized for small models
class SummaryPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You summarize educational content for students grades 5-10.
Use clear, simple language. Be accurate and concise.''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final style = params['style'] as String? ?? 'bullet';
    final maxPoints = params['maxPoints'] as int? ?? 5;

    if (style == 'bullet') {
      return '''Summarize in $maxPoints bullet points:
• [Key point 1]
• [Key point 2]
...''';
    } else {
      return '''Write a 3-4 sentence summary of the main ideas.''';
    }
  }
}

/// Prompt template for explaining concepts
/// Optimized for small models with structured output
class ExplainPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You explain concepts simply for students grades 5-10.
Use analogies and examples. Format with clear sections.''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final concept = params['concept'] as String? ?? '';

    return '''Explain: $concept

Format your answer as:
**What it is**: Simple definition
**Think of it like**: Everyday analogy  
**How it works**: Step-by-step explanation
**Key takeaway**: One memorable sentence''';
  }
}

/// Prompt template for generating chat titles
/// Ultra-minimal for speed
class TitleGeneratorPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt => '''Generate a 3-5 word title. Output ONLY the title.''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final message = params['message'] as String? ?? '';
    // Truncate long messages to save tokens
    final truncated = message.length > 100 ? message.substring(0, 100) : message;
    return '''Title for: "$truncated"''';
  }
}

/// Prompt template for generating practice worksheets
/// Outputs structured JSON for parsing
class WorksheetPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt => '''You generate practice worksheets for students.
Create problems SIMILAR to but NOT identical to the examples in the source material.
Vary difficulty within the requested level.

OUTPUT FORMAT (strict JSON array):
[
  {"question": "problem text", "answer": "solution", "steps": ["step1", "step2"], "difficulty": "easy"},
  {"question": "problem text", "answer": "solution", "steps": ["step1"], "difficulty": "medium"}
]

RULES:
• Generate ONLY the JSON array, no other text
• Each problem must have question, answer, steps (array), difficulty
• Steps should show work for math/science problems
• Difficulty must be: easy, medium, or hard
• Problems should test understanding, not just memorization''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final count = params['problemCount'] as int? ?? 10;
    final gradeLevel = params['gradeLevel'] as int? ?? 6;
    final subject = params['subject'] as String? ?? 'math';
    final difficulty = params['difficulty'] as String? ?? 'medium';
    final topic = params['topic'] as String? ?? '';

    final topicLine = topic.isNotEmpty ? 'Topic focus: $topic\n' : '';

    return '''${topicLine}Generate $count practice problems for grade $gradeLevel $subject.
Difficulty level: $difficulty
Base problems on the examples and concepts in the source material above.
Output ONLY a valid JSON array.''';
  }
}

/// Factory for creating prompt templates
class PromptFactory {
  static final Map<PromptType, PromptTemplate> _templates = {
    PromptType.qa: QAPromptTemplate(),
    PromptType.quiz: QuizPromptTemplate(),
    PromptType.summary: SummaryPromptTemplate(),
    PromptType.explain: ExplainPromptTemplate(),
    PromptType.title: TitleGeneratorPromptTemplate(),
    PromptType.worksheet: WorksheetPromptTemplate(),
  };

  static PromptTemplate get(PromptType type) {
    return _templates[type] ?? QAPromptTemplate();
  }
}

enum PromptType { qa, quiz, summary, explain, title, worksheet }
