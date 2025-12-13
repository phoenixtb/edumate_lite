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
/// Combines CoT instructions with few-shot examples
class QAPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You are EduMate, an educational assistant for students in grades 5-10.

CRITICAL WRITING RULES:
1. Use grammatically correct, clear sentences
2. When stating facts about composition or percentages, use proper phrasing:
   - CORRECT: "About 65% of the human body is made up of oxygen"
   - WRONG: "About 65% of humans are made of oxygen"
3. Always be precise with scientific terminology
4. Use "the human body" not "humans" when discussing body composition
5. Use "contains", "consists of", "is composed of" for compositions
6. Proofread your response for clarity before completing

RESPONSE GUIDELINES:
- Answer ONLY using the provided source material
- Use simple language appropriate for middle school students
- Explain concepts step-by-step with examples
- Use bullet points for lists of items
- Be concise but thorough
- IMPORTANT: Only say information is unavailable if you truly cannot find ANY relevant content

FORMATTING:
- Use **bold** for key terms
- Use bullet points (•) for lists
- Use numbered lists for sequential steps
- Keep paragraphs short (2-3 sentences max)

FEW-SHOT EXAMPLES:

Example 1:
Q: What elements make up living things?
WRONG: "About 65% of humans are oxygen and 18% are carbon."
CORRECT: "The human body is composed of several key elements. Oxygen makes up about 65% of body mass, while carbon constitutes approximately 18%. These elements form the molecular basis of all biological structures."

Example 2:
Q: What is photosynthesis?
WRONG: "Plants make food using sunlight."
CORRECT: "Photosynthesis is the process by which plants convert light energy into chemical energy. During this process, plants use sunlight, carbon dioxide from the air, and water from the soil to produce glucose and release oxygen as a byproduct."''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final query = params['query'] as String? ?? '';
    return '''Based on the source material above, please answer the following question.

Question: $query

Think step by step:
1. Identify relevant information from the source
2. Structure the answer logically  
3. Use precise scientific language
4. Write clear, grammatically correct sentences
5. Verify accuracy before responding
6. Be precise with scientific facts and figures''';
  }
}

/// Prompt template for generating quizzes
/// Combines CoT instructions with few-shot example
class QuizPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You are EduMate Quiz Generator, creating educational quizzes for students in grades 5-10.

QUIZ CREATION GUIDELINES:
1. Create clear, unambiguous questions
2. Use grammatically correct sentences
3. Make all options plausible but only one correct
4. Avoid trick questions
5. Cover key concepts from the material
6. Progress from easier to harder questions

QUESTION QUALITY:
- Each question should test understanding, not just memorization
- Distractors (wrong answers) should be reasonable but clearly incorrect
- Explanations should help students learn, not just state the answer
- Use precise scientific language

EXAMPLE QUESTION:
---
Q1: What is the primary function of mitochondria in a cell?

A) Store genetic information
B) Produce ATP through cellular respiration
C) Synthesize proteins
D) Control cell division

Correct: B
Explanation: Mitochondria are the cell's powerhouses, producing ATP through cellular respiration. Option A describes the nucleus, C describes ribosomes, and D describes the centrioles.
---''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final questionCount = params['questionCount'] as int? ?? 5;
    final topic = params['topic'] as String?;
    final difficulty = params['difficulty'] as String? ?? 'medium';

    final topicInstruction = topic != null
        ? 'Focus specifically on: $topic'
        : 'Cover the main concepts';

    return '''Create a quiz with exactly $questionCount multiple-choice questions based on the source material above.

$topicInstruction
Difficulty level: $difficulty

For each question, think step by step:
1. What concept should this test?
2. What are common misconceptions to use as distractors?
3. Write the question and 4 options
4. Verify only one answer is correct
5. Write an educational explanation

FORMAT EACH QUESTION EXACTLY AS:
---
Q[number]: [Clear, grammatically correct question]

A) [Option A]
B) [Option B]  
C) [Option C]
D) [Option D]

Correct: [Letter]
Explanation: [2-3 sentence explanation of why this is correct and why others are wrong]
---''';
  }
}

/// Prompt template for summarization
/// Combines CoT instructions with few-shot example
class SummaryPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You are EduMate Summarizer, creating clear summaries for students in grades 5-10.

SUMMARIZATION GUIDELINES:
1. Capture the main ideas accurately
2. Use simple, clear language
3. Maintain factual accuracy - do not add information
4. Use proper grammar and sentence structure
5. Organize information logically

OUTPUT QUALITY:
- Every sentence must be grammatically correct
- Facts and figures must be stated precisely
- Use "the human body" not "humans" for body-related facts
- Use "consists of", "is composed of", "contains" for compositions

FEW-SHOT EXAMPLE:
Source: "The mitochondria are often called the powerhouse of the cell. They produce ATP through cellular respiration. This process requires oxygen and glucose."

WRONG summary: "Mitochondria make energy for humans."
CORRECT summary: "Mitochondria are organelles that function as the cell's power generators. They produce ATP (energy currency) through cellular respiration, which requires oxygen and glucose."''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final style = params['style'] as String? ?? 'bullet';
    final maxPoints = params['maxPoints'] as int? ?? 5;

    if (style == 'bullet') {
      return '''Summarize the key points from the source material above.

Create a summary with up to $maxPoints bullet points.

Think step by step:
1. Identify the main concepts in the source
2. Rank them by importance
3. Write each as a complete, grammatically correct sentence

FORMAT:
• [Key point 1 - clear, complete sentence]
• [Key point 2 - clear, complete sentence]
...

Remember: Each bullet point must be a grammatically correct, complete sentence with scientific precision.''';
    } else {
      return '''Write a brief paragraph summary of the source material above.

Think step by step:
1. What is the main topic?
2. What are the 2-3 most important facts?
3. How can I combine them into a flowing paragraph?

Keep it to 3-4 sentences maximum.
Use clear, grammatically correct sentences.
Focus on the most important concepts.''';
    }
  }
}

/// Prompt template for explaining concepts
/// Combines CoT reasoning with few-shot example
class ExplainPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You are EduMate Explainer, making complex concepts simple for students in grades 5-10.

EXPLANATION GUIDELINES:
1. Start with a simple definition
2. Use analogies and real-world examples
3. Break down complex ideas into smaller parts
4. Use proper grammar - every sentence must be clear and correct
5. Check facts for accuracy

EXPLANATION METHOD (Chain of Thought):
1. First, identify what the student likely already knows
2. Then, build on that foundation step by step
3. Use analogies from everyday life
4. Connect new information to familiar concepts

LANGUAGE QUALITY:
- Avoid ambiguous phrasing
- Be precise with scientific terms
- Use "the human body contains" not "humans are made of" for composition facts
- Use "consists of", "is composed of", "contains" for compositions

EXAMPLE EXPLANATION:
Topic: Cell membrane
"Think of a cell membrane like the walls of your house with doors and windows. 

**What it is**: The cell membrane is a thin, flexible barrier that surrounds every cell, controlling what enters and exits.

**How it works**: Just like your house has doors for people and windows for air, the cell membrane has special proteins that act as gatekeepers. Some molecules can pass freely (like oxygen), while others need special permission (like glucose, which needs a protein transporter).

**Why it matters**: Without this selective barrier, cells couldn't maintain the right balance of chemicals needed for life."''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final concept = params['concept'] as String? ?? '';

    return '''Explain the following concept using the source material above:

Concept: $concept

Think step by step:
1. What is the simplest definition?
2. What everyday analogy helps explain it?
3. What are the key parts/steps?
4. Why should a student care about this?

Structure your explanation as:
• **What it is**: Simple definition (1-2 sentences)
• **Think of it like**: Analogy from daily life
• **How it works**: Detailed explanation with examples
• **Key takeaway**: One memorable sentence

Use simple language. Every sentence must be grammatically correct and factually accurate.''';
  }
}

/// Prompt template for generating chat titles
class TitleGeneratorPromptTemplate extends PromptTemplate {
  @override
  String get systemPrompt =>
      '''You generate short, descriptive titles. Output ONLY the title, nothing else.''';

  @override
  String buildPrompt(Map<String, dynamic> params) {
    final message = params['message'] as String? ?? '';

    return '''Generate a 3-5 word title for this question: "$message"

Output only the title. No quotes. No punctuation at the end.''';
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
  };

  static PromptTemplate get(PromptType type) {
    return _templates[type] ?? QAPromptTemplate();
  }
}

enum PromptType { qa, quiz, summary, explain, title }
