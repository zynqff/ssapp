import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import 'privacy_policy_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool startWithRegister;
  const LoginScreen({super.key, this.startWithRegister = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late bool _isRegister;

  final _loginCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.startWithRegister;
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passCtrl.text;

    if (_isRegister) {
      final email    = _emailCtrl.text.trim();
      final username = _usernameCtrl.text.trim();
      if (email.isEmpty || username.isEmpty || password.isEmpty) {
        setState(() => _error = 'Заполните все поля');
        return;
      }
      setState(() { _loading = true; _error = null; _info = null; });
      final result = await ref.read(authProvider.notifier).register(email, password, username);

      if (!mounted) return;

      if (result == null) {
        setState(() => _loading = false);
      } else if (result.startsWith('confirm_email:')) {
        final sentTo = result.substring('confirm_email:'.length);
        setState(() {
          _loading = false;
          _info = 'Письмо отправлено на $sentTo. Подтвердите email и войдите.';
          _isRegister = false;
        });
      } else {
        setState(() { _loading = false; _error = result; });
      }
    } else {
      final login = _loginCtrl.text.trim();
      if (login.isEmpty || password.isEmpty) {
        setState(() => _error = 'Заполните все поля');
        return;
      }
      setState(() { _loading = true; _error = null; _info = null; });
      final error = await ref.read(authProvider.notifier).login(login, password);
      if (mounted) setState(() { _loading = false; _error = error; });
    }
  }

  Future<void> _googleLogin() async {
    setState(() { _loading = true; _error = null; _info = null; });
    final error = await ref.read(authProvider.notifier).loginWithGoogle();
    if (mounted) setState(() { _loading = false; _error = error; });
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final config = ref.watch(configProvider).valueOrNull;
    final googleEnabled       = config?.googleSigninEnabled ?? true;
    final registrationEnabled = config?.registrationEnabled ?? true;

    if (_isRegister && !registrationEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isRegister = false);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),

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

                // ── Поля входа ──────────────────────────────────────────────
                if (!_isRegister) ...[
                  _StyledField(
                    controller: _loginCtrl,
                    label: 'Имя пользователя или Email',
                    icon: Icons.person_outline_rounded,
                    action: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Поля регистрации ────────────────────────────────────────
                if (_isRegister) ...[
                  _StyledField(
                    controller: _usernameCtrl,
                    label: 'Имя пользователя',
                    icon: Icons.person_outline_rounded,
                    action: TextInputAction.next,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  _StyledField(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    action: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Пароль ──────────────────────────────────────────────────
                _StyledField(
                  controller: _passCtrl,
                  label: 'Пароль',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  action: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),

                // ── Забыли пароль? (только на форме входа) ─────────────────
                if (!_isRegister) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _openForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Забыли пароль?',
                        style: GoogleFonts.notoSerif(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Info ────────────────────────────────────────────────────
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: cs.primary.withOpacity(0.3), width: 0.8),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded,
                          color: cs.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _info!,
                          style: GoogleFonts.notoSerif(
                              color: cs.primary, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                ],

                // ── Error ───────────────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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

                // ── Кнопка входа/регистрации ────────────────────────────────
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
                                strokeWidth: 2, color: cs.onPrimary),
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

                // ── Google ──────────────────────────────────────────────────
                if (googleEnabled) ...[
                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: cs.outline.withOpacity(0.5))),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('или',
                          style: GoogleFonts.notoSerif(
                              color: cs.onSurfaceVariant,
                              fontSize: 13)),
                    ),
                    Expanded(
                        child: Divider(
                            color: cs.outline.withOpacity(0.5))),
                  ]),
                  const SizedBox(height: 16),
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
                            fontSize: 14, color: cs.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Переключение вход/регистрация ───────────────────────────
                if (registrationEnabled) ...[
                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _error = null;
                      _info = null;
                    }),
                    child: Text(
                      _isRegister
                          ? 'Уже есть аккаунт? Войти'
                          : 'Нет аккаунта? Зарегистрироваться',
                      style: GoogleFonts.notoSerif(
                          color: cs.primary, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // ── Политика конфиденциальности ─────────────────────────────
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

// ── Экран сброса пароля ────────────────────────────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Введите email');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final error = await ref.read(authProvider.notifier).resetPassword(email);
    if (!mounted) return;

    if (error == null) {
      setState(() { _loading = false; _sent = true; });
    } else {
      setState(() { _loading = false; _error = error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline, width: 0.8),
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: cs.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Сброс пароля',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _sent ? _buildSuccess(cs) : _buildForm(cs),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),

        // Иконка
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.primary.withOpacity(0.3),
              width: 1.2,
            ),
          ),
          child: Icon(Icons.lock_reset_rounded, size: 34, color: cs.primary),
        ),
        const SizedBox(height: 20),

        Text(
          'Забыли пароль?',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Введите email, на который зарегистрирован аккаунт.\nМы отправим ссылку для сброса пароля.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant,
            fontSize: 13.5,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 32),

        _StyledField(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          action: TextInputAction.done,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _submit(),
        ),

        // Error
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: cs.error.withOpacity(0.3), width: 0.8),
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
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : Text(
                    'Отправить письмо',
                    style: GoogleFonts.notoSerif(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSuccess(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.primary.withOpacity(0.3),
              width: 1.2,
            ),
          ),
          child: Icon(Icons.mark_email_read_outlined,
              size: 34, color: cs.primary),
        ),
        const SizedBox(height: 20),
        Text(
          'Письмо отправлено',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Мы отправили ссылку для сброса пароля на\n${_emailCtrl.text.trim()}\n\nПроверьте папку «Спам», если письмо не пришло.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant,
            fontSize: 13.5,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Вернуться ко входу',
              style: GoogleFonts.notoSerif(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Общий виджет поля ──────────────────────────────────────────────────────

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final TextInputType keyboardType;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.suffix,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      keyboardType: keyboardType,
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
