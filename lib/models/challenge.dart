/// CTF challenge from the `public.challenges` table.
///
/// `solutionContext` is included in the model only because the Edge
/// Function reads the challenge by id server-side anyway — the client
/// never sends it back. Clients only display title/description/hints.
class Challenge {
  final String id;
  final String slug;
  final String title;
  final String category;
  final String difficulty;
  final String description;
  final List<String> hints;
  final String learningObjective;
  final String? solutionContext;

  const Challenge({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.description,
    required this.hints,
    required this.learningObjective,
    this.solutionContext,
  });

  factory Challenge.fromMap(Map<String, dynamic> map) {
    final rawHints = map['hints'];
    final hints = rawHints is List
        ? rawHints.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return Challenge(
      id: map['id'] as String,
      slug: map['slug'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      difficulty: map['difficulty'] as String,
      description: map['description'] as String,
      hints: hints,
      learningObjective: map['learning_objective'] as String,
      solutionContext: map['solution_context'] as String?,
    );
  }
}
