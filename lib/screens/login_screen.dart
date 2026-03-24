import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import 'privacy_policy_screen.dart';

// Шаги экрана
enum _Step { form, code }

class LoginScreen extends ConsumerStatefulWidget {
  final bool startWithRegister;
  const LoginScreen({super.key, this.startWithRegister = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late bool _isRegister;
  _Step _step = _Step.form;

  // Форма
  final _loginCtrl    = TextEditingController(); // username или email (вход)
  final _emailCtrl    = TextEditingController(); // email (регистрация)
  final _usernameCtrl = TextEditingController(); // username (регистрация)

  // Код
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  String _resolvedEmail = ''; // email после резолва username

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
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ── Шаг 1: отправить OTP ──────────────────────────────────────────────────

  Future<void> _sendCode() async {
    setState(() { _loading = true; _error = null; _info = null; });

    if (_isRegister) {
      final username = _usernameCtrl.text.trim();
      final email    = _emailCtrl.text.trim();

      if (username.isEmpty || email.isEmpty) {
        setState(() { _loading = false; _error = 'Заполните все поля'; });
        return;
      }

      // Проверяем не занят ли username
      final existing = await ref.read(authProvider.notifier)
          .resolveEmail(username);
      // resolveEmail по username — если вернул что-то, значит занят
      if (!username.contains('@') && existing != null) {
        setState(() {
          _loading = false;
          _error = 'Имя пользователя уже занято';
        });
        return;
      }

      final error = await ref.read(authProvider.notifier)
          .sendOtp(email, username: username);

      if (!mounted) return;
      if (error != null) {
        setState(() { _loading = false; _error = error; });
        return;
      }

      _resolvedEmail = email;
      setState(() {
        _loading = false;
        _step = _Step.code;
        _info = 'Код отправлен на $email';
      });
      _codeFocus.requestFocus();

    } else {
      // Вход — резолвим username → email
      final input = _loginCtrl.text.trim();
      if (input.isEmpty) {
        setState(() { _loading = false; _error = 'Введите email или имя пользователя'; });
        return;
      }

      final email = await ref.read(authProvider.notifier).resolveEmail(input);
      if (email == null) {
        setState(() { _loading = false; _error = 'Пользователь не найден'; });
        return;
      }

      final error = await ref.read(authProvider.notifier).sendOtp(email);

      if (!mounted) return;
      if (error != null) {
        setState(() { _loading = false; _error = error; });
        return;
      }

      _resolvedEmail = email;
      setState(() {
        _loading = false;
        _step = _Step.code;
        _info = 'Код отправлен на $email';
      });
      _codeFocus.requestFocus();
    }
  }

  // ── Шаг 2: верифицировать код ─────────────────────────────────────────────

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Введите 6-значный код');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final username = _isRegister ? _usernameCtrl.text.trim() : null;
    final error = await ref.read(authProvider.notifier)
        .verifyOtp(_resolvedEmail, code, username: username);

    if (mounted) setState(() { _loading = false; _error = error; });
  }

  // ── Назад на форму ────────────────────────────────────────────────────────

  void _backToForm() {
    setState(() {
      _step = _Step.form;
      _codeCtrl.clear();
      _error = null;
      _info = null;
    });
  }

  // ── Google ────────────────────────────────────────────────────────────────

  Future<void> _googleLogin() async {
    setState(() { _loading = true; _error = null; _info = null; });
    final error = await ref.read(authProvider.notifier).loginWithGoogle();
    if (mounted) setState(() { _loading = false; _error = error; });
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _step == _Step.form
                  ? _buildForm(cs, googleEnabled, registrationEnabled)
                  : _buildCodeStep(cs),
            ),
          ),
        ),
      ),
    );
  }

  // ── Форма ─────────────────────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs, bool googleEnabled, bool registrationEnabled) {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),

        // Иконка
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.primary.withOpacity(0.3), width: 1.2),
          ),
          child: Icon(Icons.menu_book_outlined, size: 38, color: cs.primary),
        ),
        const SizedBox(height: 20),

        Text(
          'Сборник стихов',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface, fontSize: 28, fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isRegister ? 'Создать аккаунт' : 'Добро пожаловать',
          style: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant, fontSize: 14, fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 36),

        // ── Поля входа ──────────────────────────────────────────────────────
        if (!_isRegister) ...[
          _StyledField(
            controller: _loginCtrl,
            label: 'Имя пользователя или Email',
            icon: Icons.person_outline_rounded,
            action: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _sendCode(),
          ),
        ],

        // ── Поля регистрации ────────────────────────────────────────────────
        if (_isRegister) ...[
          _StyledField(
            controller: _usernameCtrl,
            label: 'Имя пользователя',
            icon: Icons.person_outline_rounded,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _StyledField(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            action: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _sendCode(),
          ),
        ],

        // ── Error ────────────────────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 12),
          _Banner(text: _error!, isError: true, cs: cs),
        ],

        const SizedBox(height: 24),

        // ── Кнопка отправки кода ─────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _loading ? null : _sendCode,
            child: _loading
                ? SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : Text(
                    _isRegister ? 'Зарегистрироваться' : 'Получить код',
                    style: GoogleFonts.notoSerif(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Google ────────────────────────────────────────────────────────────
        if (googleEnabled) ...[
          Row(children: [
            Expanded(child: Divider(color: cs.outline.withOpacity(0.5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('или',
                  style: GoogleFonts.notoSerif(
                      color: cs.onSurfaceVariant, fontSize: 13)),
            ),
            Expanded(child: Divider(color: cs.outline.withOpacity(0.5))),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _googleLogin,
              icon: Icon(Icons.g_mobiledata, size: 26, color: cs.primary),
              label: Text('Войти через Google',
                  style: GoogleFonts.notoSerif(fontSize: 14, color: cs.primary)),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Переключение вход/регистрация ─────────────────────────────────────
        if (registrationEnabled)
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
              style: GoogleFonts.notoSerif(color: cs.primary, fontSize: 13),
            ),
          ),
        const SizedBox(height: 8),

        // ── Политика ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant, fontSize: 11.5, height: 1.5,
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
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Экран ввода кода ──────────────────────────────────────────────────────

  Widget _buildCodeStep(ColorScheme cs) {
    return Column(
      key: const ValueKey('code'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),

        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.primary.withOpacity(0.3), width: 1.2),
          ),
          child: Icon(Icons.mark_email_read_outlined, size: 38, color: cs.primary),
        ),
        const SizedBox(height: 20),

        Text(
          'Введите код',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface, fontSize: 26, fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Мы отправили 6-значный код на\n$_resolvedEmail',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant,
            fontSize: 13.5,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 36),

        // Поле кода — крупные цифры по центру
        TextField(
          controller: _codeCtrl,
          focusNode: _codeFocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: 12,
          ),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: GoogleFonts.playfairDisplay(
              color: cs.onSurfaceVariant.withOpacity(0.4),
              fontSize: 32,
              letterSpacing: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline, width: 0.9),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
            filled: true,
            fillColor: cs.surfaceVariant.withOpacity(0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          ),
          onChanged: (v) {
            if (v.length == 6) _verifyCode();
          },
          onSubmitted: (_) => _verifyCode(),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          _Banner(text: _error!, isError: true, cs: cs),
        ],

        if (_info != null) ...[
          const SizedBox(height: 14),
          _Banner(text: _info!, isError: false, cs: cs),
        ],

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _loading ? null : _verifyCode,
            child: _loading
                ? SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : Text(
                    'Подтвердить',
                    style: GoogleFonts.notoSerif(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Повторная отправка
        TextButton(
          onPressed: _loading ? null : () async {
            setState(() { _loading = true; _error = null; _info = null; });
            final username = _isRegister ? _usernameCtrl.text.trim() : null;
            final error = await ref.read(authProvider.notifier)
                .sendOtp(_resolvedEmail, username: username);
            if (mounted) setState(() {
              _loading = false;
              _error = error;
              _info = error == null ? 'Новый код отправлен' : null;
            });
          },
          child: Text(
            'Отправить код повторно',
            style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: _loading ? null : _backToForm,
          child: Text(
            '← Назад',
            style: GoogleFonts.notoSerif(color: cs.primary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Баннер ────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String text;
  final bool isError;
  final ColorScheme cs;
  const _Banner({required this.text, required this.isError, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = isError ? cs.error : cs.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          color: color, size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.notoSerif(color: color, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Поле ввода ────────────────────────────────────────────────────────────────

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      textInputAction: action,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: GoogleFonts.notoSerif(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant, fontSize: 13),
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 20),
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
