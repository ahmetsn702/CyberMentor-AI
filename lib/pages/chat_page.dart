import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/challenge.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String category;
  final String? conversationId;
  final Challenge? challenge;

  const ChatPage({
    super.key,
    required this.category,
    this.conversationId,
    this.challenge,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, String>> _apiHistory = [];
  final Set<String> _knownMessageIds = <String>{};
  bool _isLoading = false;
  String? _conversationId;
  RealtimeChannel? _channel;
  // AI_BUSY (Edge Function 503) durumunda gösterilen retry banner mesajı.
  // Null = banner gizli. Yeni mesaj gönderilirken veya retry başlatılınca
  // null'a sıfırlanır.
  String? _retryableError;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      _loadHistory().then((_) => _subscribeToMessages());
    } else {
      _messages.add({
        'role': 'assistant',
        'text': _initialWelcomeMessage(),
      });
    }
  }

  /// Yeni bir konuşma açıldığında gösterilecek karşılama mesajı.
  /// Challenge bağlamında açıldıysa challenge-aware bir mesaj döner; aksi
  /// halde kategori için varsayılan karşılama döner.
  String _initialWelcomeMessage() {
    final challenge = widget.challenge;
    if (challenge == null) {
      return ChatService.getWelcomeMessage(widget.category);
    }
    return 'Birlikte **${challenge.title}** challenge\'ı üzerinde çalışacağız.\n\n'
        '${challenge.description}\n\n'
        'Nereden başlamak istersin? Hangi adımdan emin değilsin? '
        'Sokratik yöntemle adım adım ilerleyeceğiz — doğrudan cevap '
        'beklemek yerine yönlendirici sorular bekle.';
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _supabase
          .from('messages')
          .select('id, role, content')
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true);
      for (final row in rows) {
        final id = row['id'] as String;
        final role = row['role'] as String;
        final content = row['content'] as String;
        _knownMessageIds.add(id);
        _messages.add({'role': role, 'text': content, 'id': id});
        _apiHistory.add({'role': role, 'content': content});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geçmiş yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _ensureConversation(String firstMessage) async {
    if (_conversationId != null) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    // Challenge bağlamında açıldıysa title olarak challenge başlığını kullan
    // — geçmiş listesinde "Login Bypass" görmek "admin'-- yazmayı..." dan
    // çok daha okunaklı.
    final challenge = widget.challenge;
    final title = challenge != null
        ? challenge.title
        : (firstMessage.length > 50
            ? '${firstMessage.substring(0, 50)}...'
            : firstMessage);
    final row = await _supabase
        .from('conversations')
        .insert({
          'user_id': userId,
          'category': widget.category,
          'title': title,
          if (challenge != null) 'challenge_id': challenge.id,
        })
        .select('id')
        .single();
    _conversationId = row['id'] as String;
    _subscribeToMessages();
  }

  Future<void> _persistMessage(String role, String content) async {
    if (_conversationId == null) return;
    try {
      final row = await _supabase
          .from('messages')
          .insert({
            'conversation_id': _conversationId,
            'role': role,
            'content': content,
          })
          .select('id')
          .single();
      final id = row['id'] as String;
      _knownMessageIds.add(id);
      final localIdx = _messages.lastIndexWhere(
        (m) => m['id'] == null && m['role'] == role && m['text'] == content,
      );
      if (localIdx != -1) {
        _messages[localIdx]['id'] = id;
      }
    } catch (_) {
      // Best-effort; in-memory chat still works.
    }
  }

  void _subscribeToMessages() {
    debugPrint('[Realtime] _subscribeToMessages called '
        '(conversationId=$_conversationId, channelExists=${_channel != null})');
    if (_conversationId == null || _channel != null) {
      debugPrint('[Realtime] _subscribeToMessages skipped');
      return;
    }
    _channel = _supabase
        .channel('messages:$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId!,
          ),
          callback: _handleRemoteInsert,
        )
        .subscribe((status, [error]) {
          debugPrint('[Realtime] channel status=$status error=$error');
        });
    debugPrint('[Realtime] channel created for messages:$_conversationId');
  }

  void _handleRemoteInsert(PostgresChangePayload payload) {
    debugPrint('[Realtime] _handleRemoteInsert fired: newRecord=${payload.newRecord}');
    final row = payload.newRecord;
    final id = row['id'] as String?;
    if (id == null || _knownMessageIds.contains(id)) {
      debugPrint('[Realtime] skipped (id=$id, known=${_knownMessageIds.contains(id)})');
      return;
    }

    final role = row['role'] as String?;
    final content = row['content'] as String?;
    if (role == null || content == null) {
      debugPrint('[Realtime] skipped (missing role/content)');
      return;
    }

    // Claim this id for a matching local optimistic message (race:
    // realtime echo arrives before the insert's REST response).
    final localIdx = _messages.lastIndexWhere(
      (m) => m['id'] == null && m['role'] == role && m['text'] == content,
    );
    if (localIdx != -1) {
      _knownMessageIds.add(id);
      _messages[localIdx]['id'] = id;
      return;
    }

    _knownMessageIds.add(id);
    if (!mounted) return;
    setState(() {
      _messages.add({'role': role, 'text': content, 'id': id});
    });
    _apiHistory.add({'role': role, 'content': content});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
      _retryableError = null;
    });
    _apiHistory.add({'role': 'user', 'content': text});
    _scrollToBottom();

    try {
      await _ensureConversation(text);
    } catch (_) {
      // Continue in memory if conversation create fails.
    }
    await _persistMessage('user', text);

    final result = await ChatService.sendMessage(
      _apiHistory,
      widget.category,
      challengeId: widget.challenge?.id,
    );
    await _handleResult(result);
  }

  /// Banner üzerindeki "Tekrar dene" → son user mesajını re-send eder.
  /// _apiHistory zaten doğru durumda (son entry user); yeni mesaj/persist yok.
  Future<void> _retryLastMessage() async {
    if (_isLoading) return;
    if (_apiHistory.isEmpty || _apiHistory.last['role'] != 'user') return;

    setState(() {
      _isLoading = true;
      _retryableError = null;
    });
    _scrollToBottom();

    final result = await ChatService.sendMessage(
      _apiHistory,
      widget.category,
      challengeId: widget.challenge?.id,
    );
    await _handleResult(result);
  }

  /// Send/retry sonrası ortak işleme. Sealed pattern match: success →
  /// asistan mesajı + persist; busy/rateLimited → banner + apiHistory'i
  /// koru (retry için); error → snackbar + persist etme.
  ///
  /// Busy ve RateLimited UI'da aynı banner'ı paylaşır — ikisi de
  /// "geçici, beklenip tekrar denenebilir" semantiğinde, mesaj farklı.
  Future<void> _handleResult(ChatResult result) async {
    if (!mounted) return;
    switch (result) {
      case ChatSuccess(:final reply):
        _apiHistory.add({'role': 'assistant', 'content': reply});
        setState(() {
          _messages.add({'role': 'assistant', 'text': reply});
          _isLoading = false;
          _retryableError = null;
        });
        _scrollToBottom();
        await _persistMessage('assistant', reply);
      case ChatBusy(:final message):
        setState(() {
          _isLoading = false;
          _retryableError = message;
        });
      case ChatRateLimited(:final message):
        setState(() {
          _isLoading = false;
          _retryableError = message;
        });
      case ChatError(:final message):
        setState(() {
          _isLoading = false;
          _retryableError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildRetryBanner(String message) {
    // Amber: error red'inden ayrışsın — bu transient bir durum, kalıcı bir
    // hata değil. Aynı renk kodu challenge difficulty "Orta" badge'inde de
    // var (intentional: "warning" semantik tutarlılığı).
    const amber = Color(0xFFD97706);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _retryLastMessage,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tekrar dene'),
            style: TextButton.styleFrom(foregroundColor: amber),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.category} Mentor',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'CyberMentor AI',
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _ChatBubble(
                  text: msg['text'] as String,
                  isUser: isUser,
                );
              },
            ),
          ),
          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CyberMentor düşünüyor...',
                    style: TextStyle(color: colorScheme.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
          // Retry banner — AI_BUSY (transient). Mutually exclusive with the
          // loading indicator: _retryableError only set when _isLoading false.
          if (_retryableError != null) _buildRetryBanner(_retryableError!),
          // Message input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Sorunuzu yazın...',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    // Keep primary color while spinner is shown, instead of
                    // the muted "disabled" look.
                    disabledBackgroundColor: colorScheme.primary,
                    disabledForegroundColor: colorScheme.onPrimary,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: const Icon(Icons.security_rounded, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
              ),
              child: isUser
                  ? SelectableText(
                      text,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        strong: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: colorScheme.onSurface,
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          color: colorScheme.primary,
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.1),
                          fontSize: 14,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        codeblockPadding: const EdgeInsets.all(12),
                        listBullet: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 15,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        blockquotePadding:
                            const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                        h1: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
