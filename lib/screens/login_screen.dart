import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool startWithRegister;
  const LoginScreen({super.key, this.startWithRegister = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late bool _isRegister;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.startWithRegister;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final notifier = ref.read(authProvider.notifier);
    String? error;
    if (_isRegister) {
      error = await notifier.register(u, p);
      if (error == null) error = await notifier.login(u, p);
    } else {
      error = await notifier.login(u, p);
    }
    if (mounted) setState(() { _loading = false; _error = error; });
  }

  Future<void> _googleLogin() async {
    setState(() { _loading = true; _error = null; });
    final error = await ref.read(authProvider.notifier).loginWithGoogle();
    if (mounted) setState(() { _loading = false; _error = error; });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Icon(Icons.menu_book_outlined, size: 72, color: t.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Сборник стихов',
                    style: t.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isRegister ? 'Создать аккаунт' : 'Добро пожаловать',
                    style: t.textTheme.bodyLarge
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),

                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя пользователя',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: t.colorScheme.onErrorContainer, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: TextStyle(color: t.colorScheme.onErrorContainer))),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
                  ),
                ),
                const SizedBox(height: 12),

                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('или', style: t.textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _googleLogin,
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Войти через Google'),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => setState(() { _isRegister = !_isRegister; _error = null; }),
                  child: Text(_isRegister
                      ? 'Уже есть аккаунт? Войти'
                      : 'Нет аккаунта? Зарегистрироваться'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
