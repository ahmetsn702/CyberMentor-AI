import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'challenges_page.dart';
import 'chat_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = Supabase.instance.client.auth.currentUser;

  static const List<Map<String, dynamic>> _categories = [
    {
      'title': 'SQL Injection',
      'icon': Icons.storage_rounded,
      'color': Color(0xFF7C3AED),
    },
    {
      'title': 'Network Security',
      'icon': Icons.lan_rounded,
      'color': Color(0xFF0891B2),
    },
    {
      'title': 'Linux',
      'icon': Icons.terminal_rounded,
      'color': Color(0xFF059669),
    },
    {
      'title': 'Cryptography',
      'icon': Icons.lock_rounded,
      'color': Color(0xFFD97706),
    },
  ];

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryPage()),
    );
  }

  void _openChat(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(category: category),
      ),
    );
  }

  void _openChallenges() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChallengesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CyberMentor AI'),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Geçmiş',
          ),
          IconButton(
            onPressed: _openProfile,
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Hoş geldin! 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 32),
            Text(
              'Hangi konuyu çalışmak istiyorsun?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Category grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: _categories.map((cat) {
                  return _CategoryCard(
                    title: cat['title'] as String,
                    icon: cat['icon'] as IconData,
                    color: cat['color'] as Color,
                    onTap: () => _openChat(cat['title'] as String),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Challenge bankası — kategorilerden farklı bir akış: somut
            // bir challenge üzerinde AI mentor desteğiyle çalışma.
            FilledButton.icon(
              onPressed: _openChallenges,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Challenge Bankası'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
