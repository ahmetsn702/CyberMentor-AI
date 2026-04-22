import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/challenge.dart';
import 'challenge_detail_page.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Challenge>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Challenge>> _load() async {
    // category sıralı + zorluk sıralı: aynı kategori grupları yan yana,
    // her grupta önce kolaylar.
    final rows = await _supabase
        .from('challenges')
        .select(
          'id, slug, title, category, difficulty, description, hints, '
          'learning_objective, solution_context',
        )
        .order('category', ascending: true)
        .order('difficulty', ascending: true);
    return rows
        .map((row) => Challenge.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge Bankası')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Challenge>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _buildError(context, snap.error.toString());
            }
            final items = snap.data ?? const <Challenge>[];
            if (items.isEmpty) {
              return _buildEmpty(context);
            }
            return _buildList(items);
          },
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Center(
          child: Column(
            children: [
              Icon(Icons.flag_outlined, size: 72, color: cs.outline),
              const SizedBox(height: 16),
              Text(
                'Henüz challenge yok',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Challenge bankası seed edilmemiş olabilir. '
                  'supabase/seed.sql dosyasını çalıştırmayı dene.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'Challenge\'lar yüklenemedi',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Challenge> items) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = items[i];
        return _ChallengeTile(
          challenge: c,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChallengeDetailPage(challenge: c),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;

  const _ChallengeTile({required this.challenge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _categoryColor(challenge.category).withValues(
          alpha: 0.15,
        ),
        child: Icon(
          _iconFor(challenge.category),
          color: _categoryColor(challenge.category),
          size: 22,
        ),
      ),
      title: Text(
        challenge.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          challenge.category,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      trailing: _DifficultyBadge(difficulty: challenge.difficulty),
      onTap: onTap,
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'SQL Injection':
        return Icons.storage_rounded;
      case 'Network Security':
        return Icons.lan_rounded;
      case 'Linux':
        return Icons.terminal_rounded;
      case 'Cryptography':
        return Icons.lock_rounded;
      default:
        return Icons.flag_outlined;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'SQL Injection':
        return const Color(0xFF7C3AED);
      case 'Network Security':
        return const Color(0xFF0891B2);
      case 'Linux':
        return const Color(0xFF059669);
      case 'Cryptography':
        return const Color(0xFFD97706);
      default:
        return Colors.grey;
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _colorFor(String difficulty) {
    switch (difficulty) {
      case 'Kolay':
        return const Color(0xFF059669);
      case 'Orta':
        return const Color(0xFFD97706);
      case 'Zor':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }
}
