/// Represents a generated practice worksheet
class Worksheet {
  final String title;
  final List<Problem> problems;
  final DateTime generatedAt;
  final int gradeLevel;
  final String subject;
  final String? topic;
  final String difficulty;

  /// Source material IDs used to generate this worksheet
  final List<int> materialIds;

  Worksheet({
    required this.title,
    required this.problems,
    required this.gradeLevel,
    required this.subject,
    this.topic,
    required this.difficulty,
    required this.materialIds,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Total number of problems
  int get problemCount => problems.length;

  /// Count problems by difficulty
  Map<String, int> get difficultyBreakdown {
    final counts = <String, int>{'easy': 0, 'medium': 0, 'hard': 0};
    for (final p in problems) {
      counts[p.difficulty] = (counts[p.difficulty] ?? 0) + 1;
    }
    return counts;
  }
}

/// Represents a single problem in a worksheet
class Problem {
  final String question;
  final String answer;
  final List<String> steps;
  final String difficulty;

  Problem({
    required this.question,
    required this.answer,
    this.steps = const [],
    this.difficulty = 'medium',
  });

  /// Parse from JSON map (LLM output)
  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      difficulty: json['difficulty'] as String? ?? 'medium',
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'steps': steps,
        'difficulty': difficulty,
      };

  /// Check if problem has step-by-step solution
  bool get hasSteps => steps.isNotEmpty;
}

/// Configuration for worksheet generation
class WorksheetConfig {
  final List<int> materialIds;
  final int problemCount;
  final int gradeLevel;
  final String subject;
  final String? topic;
  final String difficulty; // 'easy', 'medium', 'hard', 'mixed'
  final bool includeSteps;

  WorksheetConfig({
    required this.materialIds,
    this.problemCount = 10,
    this.gradeLevel = 6,
    this.subject = 'math',
    this.topic,
    this.difficulty = 'medium',
    this.includeSteps = true,
  });
}
