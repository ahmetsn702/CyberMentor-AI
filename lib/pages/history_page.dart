import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _supabase
        .from('conversations')
        .select('id, category, title, created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final future = _load();
    // Block body — arrow form `() => _future = future` returns the assigned
    // Future, which trips setState's "callback returned a Future" check.
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _promptDelete(String id, String? title) async {
    final colorScheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sohbeti sil'),
        content: Text(
          (title != null && title.isNotEmpty)
              ? '"$title" silinsin mi? Bu işlem geri alınamaz.'
              : 'Bu sohbet silinsin mi? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _delete(id);
  }

  Future<void> _delete(String id) async {
    try {
      // RLS conversations_delete_own + FK on delete cascade clean up messages.
      await _supabase.from('conversations').delete().eq('id', id);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sohbet silinemedi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return '';
    }
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
        return Icons.chat_bubble_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konuşma Geçmişi')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _buildError(context, snap.error.toString());
            }
            final items = snap.data ?? const [];
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
    // ListView (instead of Center) so RefreshIndicator can still pull-to-refresh.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 72,
                color: cs.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz sohbet yok',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'İlk sorunu anasayfadan başlat.',
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
                  'Geçmiş yüklenemedi',
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

  Widget _buildList(List<Map<String, dynamic>> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = items[i];
        final category = c['category'] as String;
        final id = c['id'] as String;
        final title = c['title'] as String?;
        return ListTile(
          leading: Icon(_iconFor(category)),
          title: Text(
            title ?? '(başlıksız)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$category • ${_formatDate(c['created_at'] as String)}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Sil',
            onPressed: () => _promptDelete(id, title),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  category: category,
                  conversationId: id,
                ),
              ),
            );
          },
          onLongPress: () => _promptDelete(id, title),
        );
      },
    );
  }
}
