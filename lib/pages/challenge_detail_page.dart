import 'package:flutter/material.dart';
import '../models/challenge.dart';
import 'chat_page.dart';

/// Challenge detay ekranı: açıklama + öğrenme hedefi + progressive ipuçları
/// + "AI Mentor ile Çöz" CTA. solution_context sadece Edge Function'a
/// gider, kullanıcıya gösterilmez.
class ChallengeDetailPage extends StatefulWidget {
  final Challenge challenge;

  const ChallengeDetailPage({super.key, required this.challenge});

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  // Açılan ipucu sayısı. Hint i (0-indexed) açılabilir <=> i <= _revealedCount.
  // Hint i açılınca _revealedCount = max(_revealedCount, i+1).
  int _revealedCount = 0;

  void _revealHint(int index) {
    setState(() {
      if (index + 1 > _revealedCount) _revealedCount = index + 1;
    });
  }

  void _openMentor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          category: widget.challenge.category,
          challenge: widget.challenge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge satırı: zorluk + kategori
            Row(
              children: [
                _DifficultyBadge(difficulty: c.difficulty),
                const SizedBox(width: 8),
                _CategoryChip(category: c.category),
              ],
            ),
            const SizedBox(height: 20),

            // Açıklama
            _SectionCard(
              icon: Icons.description_outlined,
              title: 'Açıklama',
              body: c.description,
              accentColor: cs.primary,
            ),
            const SizedBox(height: 12),

            // Öğrenme hedefi
            _SectionCard(
              icon: Icons.school_outlined,
              title: 'Öğrenme Hedefi',
              body: c.learningObjective,
              accentColor: cs.tertiary,
            ),
            const SizedBox(height: 24),

            // CTA: AI Mentor ile çöz
            FilledButton.icon(
              onPressed: _openMentor,
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('AI Mentor ile Çöz'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // İpuçları başlığı
            Row(
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'İpuçları',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'İpuçlarını sırayla aç. Önce kendin düşün — bir sonraki ipucu, '
              'önceki açıldıktan sonra erişilebilir.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            for (int i = 0; i < c.hints.length; i++) ...[
              _HintCard(
                index: i,
                total: c.hints.length,
                text: c.hints[i],
                revealed: i < _revealedCount,
                unlocked: i <= _revealedCount,
                onReveal: () => _revealHint(i),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              body,
              style: tt.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final int index;
  final int total;
  final String text;
  final bool revealed;
  final bool unlocked;
  final VoidCallback onReveal;

  const _HintCard({
    required this.index,
    required this.total,
    required this.text,
    required this.revealed,
    required this.unlocked,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final headerColor =
        revealed ? cs.primary : (unlocked ? cs.onSurface : cs.outline);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: revealed
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant,
        ),
      ),
      color: revealed ? cs.primary.withValues(alpha: 0.04) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  revealed
                      ? Icons.lightbulb
                      : (unlocked
                          ? Icons.lightbulb_outline
                          : Icons.lock_outline_rounded),
                  size: 20,
                  color: headerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'İpucu ${index + 1} / $total',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (revealed)
              SelectableText(
                text,
                style: tt.bodyMedium?.copyWith(height: 1.5),
              )
            else if (unlocked)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('İpucunu Göster'),
                ),
              )
            else
              Text(
                'Önceki ipucunu açtıktan sonra erişilebilir.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
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

class _CategoryChip extends StatelessWidget {
  final String category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(category), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
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

  Color _colorFor(String category) {
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
