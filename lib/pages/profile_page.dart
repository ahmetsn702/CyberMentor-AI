import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  int? _totalConversations;

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _displayName {
    final raw = _user?.userMetadata?['display_name'];
    if (raw is String && raw.trim().isNotEmpty) return raw;
    return _user?.email ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadTotalConversations();
  }

  Future<void> _loadTotalConversations() async {
    try {
      final count = await Supabase.instance.client
          .from('conversations')
          .count(CountOption.exact);
      if (mounted) setState(() => _totalConversations = count);
    } catch (_) {
      // Leave as null; UI shows '...' placeholder.
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Bilinmiyor';
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'Bilinmiyor';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editDisplayName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditDisplayNameDialog(initial: _displayName),
    );
    if (newName == null) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': newName}),
      );
      // The finally setState below also rebuilds, picking up the new metadata
      // through the _displayName getter — no separate rebuild needed here.
      _showSuccess('Kullanıcı adı güncellendi.');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Kullanıcı adı güncellenemedi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<({String oldPwd, String newPwd})>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (result == null) return;

    final email = _user?.email;
    if (email == null) {
      _showError('Oturum bulunamadı.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Supabase updateUser does not verify the current password — re-sign in
      // with the old one first so a hijacked session can't silently rotate it.
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: result.oldPwd,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: result.newPwd),
      );
      _showSuccess('Şifreniz güncellendi.');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Şifre güncellenemedi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountWarningDialog(),
    );
    if (firstOk != true || !mounted) return;

    final finalOk = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountConfirmDialog(),
    );
    if (finalOk != true) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc('delete_user');
      // Session is now orphaned server-side; clearing it locally trips
      // AuthGate's listener and routes back to LoginPage.
      await Supabase.instance.client.auth.signOut();
    } on PostgrestException catch (e) {
      _showError('Hesap silinemedi: ${e.message}');
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      _showError('Hesap silinemedi.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = _user;
    final email = user?.email;
    final showEmailUnderName = email != null && email != _displayName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 48,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (showEmailUnderName) ...[
              const SizedBox(height: 4),
              Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
            const SizedBox(height: 32),

            _ProfileTile(
              icon: Icons.person_outline_rounded,
              title: 'Kullanıcı Adı',
              value: _displayName.isEmpty ? 'Belirtilmedi' : _displayName,
              trailing: const Icon(Icons.edit_outlined),
              onTap: _isLoading ? null : _editDisplayName,
            ),
            _ProfileTile(
              icon: Icons.email_outlined,
              title: 'E-posta',
              value: email ?? 'Bilinmiyor',
            ),
            _ProfileTile(
              icon: Icons.calendar_today_rounded,
              title: 'Kayıt Tarihi',
              value: _formatDate(user?.createdAt),
            ),
            _ProfileTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Toplam Sohbet',
              valueWidget: _totalConversations == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Text(
                      _totalConversations.toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            _ProfileTile(
              icon: Icons.info_outline_rounded,
              title: 'Uygulama Versiyonu',
              value: '1.0.0',
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _changePassword,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label: const Text('Şifre Değiştir'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _deleteAccount,
                icon: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
                label: Text(
                  'Hesabı Sil',
                  style: TextStyle(color: colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? valueWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.value,
    this.valueWidget,
    this.trailing,
    this.onTap,
  }) : assert(value != null || valueWidget != null,
            'Provide either value or valueWidget.');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        subtitle: valueWidget ??
            Text(value ?? '', style: const TextStyle(fontSize: 16)),
        trailing: trailing,
        onTap: onTap,
        tileColor: colorScheme.surfaceContainerHighest,
        shape: shape,
      ),
    );
  }
}

class _EditDisplayNameDialog extends StatefulWidget {
  final String initial;
  const _EditDisplayNameDialog({required this.initial});

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kullanıcı Adını Düzenle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Kullanıcı adı',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    super.dispose();
  }

  void _submit() {
    final oldP = _oldController.text;
    final newP = _newController.text;
    if (oldP.isEmpty || newP.isEmpty) return;
    Navigator.pop(context, (oldPwd: oldP, newPwd: newP));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şifre Değiştir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldController,
            obscureText: _obscureOld,
            decoration: InputDecoration(
              labelText: 'Eski şifre',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureOld
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newController,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Yeni şifre',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Değiştir'),
        ),
      ],
    );
  }
}

class _DeleteAccountWarningDialog extends StatelessWidget {
  const _DeleteAccountWarningDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 40),
      title: const Text('Hesabınızı silmek üzeresiniz'),
      content: const Text(
        'Hesabınız ve tüm konuşma geçmişiniz kalıcı olarak silinecek. '
        'Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          child: const Text('Devam Et'),
        ),
      ],
    );
  }
}

class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  static const String _confirmPhrase = 'HESAP SİL';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canDelete = _controller.text == _confirmPhrase;
    return AlertDialog(
      title: const Text('Son onay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onaylamak için aşağıya "$_confirmPhrase" yazın.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: canDelete ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          child: const Text('Hesabı Sil'),
        ),
      ],
    );
  }
}
