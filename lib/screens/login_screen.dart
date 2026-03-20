import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import 'privacy_policy_screen.dart';

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(Icons.menu_book_outlined,
                      size: 38, color: cs.primary),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Сборник стихов',
                  style: GoogleFonts.playfairDisplay(
                    color: cs.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegister ? 'Создать аккаунт' : 'Добро пожаловать',
                  style: GoogleFonts.notoSerif(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 36),

                // Username field
                _StyledField(
                  controller: _userCtrl,
                  label: 'Имя пользователя',
                  icon: Icons.person_outline_rounded,
                  action: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // Password field
                _StyledField(
                  controller: _passCtrl,
                  label: 'Пароль',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  action: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: cs.error.withOpacity(0.3), width: 0.8),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded,
                          color: cs.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.notoSerif(
                              color: cs.error, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary),
                          )
                        : Text(
                            _isRegister ? 'Зарегистрироваться' : 'Войти',
                            style: GoogleFonts.notoSerif(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                Row(children: [
                  Expanded(
                      child: Divider(color: cs.outline.withOpacity(0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('или',
                        style: GoogleFonts.notoSerif(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                  ),
                  Expanded(
                      child: Divider(color: cs.outline.withOpacity(0.5))),
                ]),
                const SizedBox(height: 16),

                // Google button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _googleLogin,
                    icon: Icon(Icons.g_mobiledata,
                        size: 26, color: cs.primary),
                    label: Text(
                      'Войти через Google',
                      style: GoogleFonts.notoSerif(
                          fontSize: 14,
                          color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Toggle register/login
                TextButton(
                  onPressed: () => setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  }),
                  child: Text(
                    _isRegister
                        ? 'Уже есть аккаунт? Войти'
                        : 'Нет аккаунта? Зарегистрироваться',
                    style: GoogleFonts.notoSerif(
                        color: cs.primary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),

                // Privacy policy notice
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.notoSerif(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: _isRegister
                              ? 'Регистрируясь, вы соглашаетесь с '
                              : 'Входя в аккаунт, вы соглашаетесь с ',
                        ),
                        TextSpan(
                          text: 'политикой конфиденциальности',
                          style: GoogleFonts.notoSerif(
                            color: cs.primary,
                            fontSize: 11.5,
                            decoration: TextDecoration.underline,
                            decorationColor: cs.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PrivacyPolicyScreen(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onSubmitted: onSubmitted,
      style: GoogleFonts.notoSerif(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant, fontSize: 13),
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 20),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        filled: true,
        fillColor: cs.surfaceVariant.withOpacity(0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
