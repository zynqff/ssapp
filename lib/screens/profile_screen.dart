import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/poems_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _passCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _loading = false;
  String? _error, _success;
  bool _bioInit = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _bioCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; _success = null; });
    final err = await ref.read(authProvider.notifier).updateProfile(
      newPassword: _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
      userData: _bioCtrl.text,
    );
    if (mounted) setState(() {
      _loading = false;
      _error = err;
      _success = err == null ? 'Сохранено!' : null;
      if (err == null) _passCtrl.clear();
    });
  }

  Future<void> _verifyKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() { _loading = true; _error = null; _success = null; });
    if (!await SyncService().isOnline()) {
      setState(() { _loading = false; _error = 'Нет интернета'; });
      return;
    }
    final ok = await ApiService().verifyAiKey(key);
    if (mounted) setState(() {
      _loading = false;
      _error = ok ? null : 'Неверный или просроченный ключ';
      _success = ok ? 'Ключ принят! AI чат доступен.' : null;
      if (ok) _keyCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);
    final poems = ref.watch(poemsProvider).value ?? [];
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_outline, size: 72, color: t.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('Вы не вошли в аккаунт'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                  icon: const Icon(Icons.login),
                  label: const Text('Войти'),
                ),
              ]),
            );
          }

          if (!_bioInit) {
            _bioCtrl.text = user.userData;
            _bioInit = true;
          }

          final readCount = user.readPoems.length;
          final total = poems.length;
          final pct = total > 0 ? ((readCount / total) * 100).round() : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Карточка профиля ──────────────────────────────────────
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: t.colorScheme.primaryContainer,
                      child: Text(user.username[0].toUpperCase(),
                          style: t.textTheme.headlineSmall?.copyWith(
                              color: t.colorScheme.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 12),
                    Text(user.username, style: t.textTheme.titleLarge),
                  ]),
                  const Divider(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _Stat(label: 'Прочитано', value: '$readCount'),
                    _Stat(label: 'Всего', value: '$total'),
                    _Stat(label: 'Прогресс', value: '$pct%'),
                  ]),
                  if (user.pinnedPoemTitle != null) ...[
                    const Divider(height: 20),
                    Row(children: [
                      Icon(Icons.push_pin, size: 14, color: t.colorScheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        'Закреплено: ${user.pinnedPoemTitle}',
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall,
                      )),
                    ]),
                  ],
                ]),
              )),
              const SizedBox(height: 12),

              // ── Настройки ─────────────────────────────────────────────
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Настройки', style: t.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Новый пароль (необязательно)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'О себе',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info_outline)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 8),
                    Text(_success!, style: const TextStyle(color: Colors.green)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: _loading ? null : _save,
                        child: const Text('Сохранить')),
                  ),
                ]),
              )),
              const SizedBox(height: 12),

              // ── AI ключ ───────────────────────────────────────────────
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Доступ к AI', style: t.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Введи ключ от администратора для использования AI-чата',
                      style: t.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _keyCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Ключ доступа',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key_outlined)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: _loading ? null : _verifyKey,
                        child: const Text('OK')),
                  ]),
                ]),
              )),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: t.colorScheme.error),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      Text(value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    ]);
  }
}
