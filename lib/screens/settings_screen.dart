import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ── Username change ──────────────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  bool _usernameLoading = false;
  String? _usernameError;
  String? _usernameSuccess;

  // ── Email change ─────────────────────────────────────────────────────────
  final _newEmailCtrl = TextEditingController();
  final _oldCodeCtrl  = TextEditingController();
  final _newCodeCtrl  = TextEditingController();

  // Шаги смены email: idle → waitOldCode → waitNewCode → done
  _EmailStep _emailStep = _EmailStep.idle;
  String _pendingNewEmail = '';

  bool _emailLoading = false;
  String? _emailError;
  String? _emailSuccess;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _newEmailCtrl.dispose();
    _oldCodeCtrl.dispose();
    _newCodeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Username logic ───────────────────────────────────────────────────────

  Future<void> _changeUsername() async {
    final newName = _usernameCtrl.text.trim();
    if (newName.isEmpty) return;
    setState(() {
      _usernameLoading = true;
      _usernameError = null;
      _usernameSuccess = null;
    });
    final err = await ref.read(authProvider.notifier).changeUsername(newName);
    if (mounted) {
      setState(() {
        _usernameLoading = false;
        _usernameError = err;
        _usernameSuccess = err == null ? 'Никнейм изменён!' : null;
      });
      if (err == null) _usernameCtrl.clear();
    }
  }

  // ── Email logic ──────────────────────────────────────────────────────────

  void _startCooldown(int seconds) {
    _resendCooldown = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _requestEmailChange() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      setState(() => _emailError = 'Введите корректный email');
      return;
    }
    setState(() { _emailLoading = true; _emailError = null; _emailSuccess = null; });

    final err = await ref.read(authProvider.notifier).requestEmailChange(newEmail);
    if (mounted) {
      setState(() {
        _emailLoading = false;
        if (err != null) {
          _emailError = err;
        } else {
          _pendingNewEmail = newEmail;
          _emailStep = _EmailStep.waitOldCode;
          _emailSuccess = 'Код отправлен на текущий email';
          _startCooldown(60);
        }
      });
    }
  }

  Future<void> _confirmOldCode() async {
    final code = _oldCodeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _emailError = 'Введите 6-значный код');
      return;
    }
    setState(() { _emailLoading = true; _emailError = null; _emailSuccess = null; });

    final err = await ref.read(authProvider.notifier).confirmOldEmailCode(code);
    if (mounted) {
      setState(() {
        _emailLoading = false;
        if (err != null) {
          _emailError = err;
        } else {
          _emailStep = _EmailStep.waitNewCode;
          _emailSuccess = 'Код отправлен на новый email';
          _startCooldown(60);
        }
      });
    }
  }

  Future<void> _confirmNewCode() async {
    final code = _newCodeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _emailError = 'Введите 6-значный код');
      return;
    }
    setState(() { _emailLoading = true; _emailError = null; _emailSuccess = null; });

    final err = await ref.read(authProvider.notifier).confirmNewEmailCode(
        _pendingNewEmail, code);
    if (mounted) {
      setState(() {
        _emailLoading = false;
        if (err != null) {
          _emailError = err;
        } else {
          _emailStep = _EmailStep.done;
          _emailSuccess = 'Email успешно изменён!';
          _newEmailCtrl.clear();
          _oldCodeCtrl.clear();
          _newCodeCtrl.clear();
        }
      });
    }
  }

  void _resetEmailFlow() {
    setState(() {
      _emailStep = _EmailStep.idle;
      _emailError = null;
      _emailSuccess = null;
      _pendingNewEmail = '';
      _newEmailCtrl.clear();
      _oldCodeCtrl.clear();
      _newCodeCtrl.clear();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).value;

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
            child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Настройки',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [

          // ── Внешний вид ────────────────────────────────────────────────
          _AppearanceCard(),
          const SizedBox(height: 12),

          // ── Настройки аккаунта (вкладка «Все») ───────────────────────
          if (user != null) ...[
            _SectionCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Отображение'),
                const SizedBox(height: 14),
                _ShowAllTabToggle(),
              ],
            )),
            const SizedBox(height: 12),

            // ── Смена никнейма ─────────────────────────────────────────
            _SectionCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Изменить никнейм'),
                const SizedBox(height: 6),
                Text(
                  'Текущий: ${user.username}',
                  style: GoogleFonts.notoSerif(
                    color: cs.onSurfaceVariant, fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _SettingsField(
                      controller: _usernameCtrl,
                      label: 'Новый никнейм',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _usernameLoading ? null : _changeUsername,
                      child: _usernameLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('OK', style: GoogleFonts.notoSerif(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                if (_usernameError != null) ...[
                  const SizedBox(height: 10),
                  _StatusMsg(text: _usernameError!, isError: true),
                ],
                if (_usernameSuccess != null) ...[
                  const SizedBox(height: 10),
                  _StatusMsg(text: _usernameSuccess!, isError: false),
                ],
              ],
            )),
            const SizedBox(height: 12),

            // ── Смена email ────────────────────────────────────────────
            _SectionCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Изменить email'),
                const SizedBox(height: 6),
                Text(
                  'После смены коды входа будут приходить на новый адрес',
                  style: GoogleFonts.notoSerif(
                    color: cs.onSurfaceVariant, fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),
                _buildEmailFlow(cs),
                if (_emailError != null) ...[
                  const SizedBox(height: 10),
                  _StatusMsg(text: _emailError!, isError: true),
                ],
                if (_emailSuccess != null) ...[
                  const SizedBox(height: 10),
                  _StatusMsg(text: _emailSuccess!, isError: false),
                ],
              ],
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailFlow(ColorScheme cs) {
    switch (_emailStep) {
      case _EmailStep.idle:
        return Row(children: [
          Expanded(
            child: _SettingsField(
              controller: _newEmailCtrl,
              label: 'Новый email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _emailLoading ? null : _requestEmailChange,
              child: _emailLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Далее', style: GoogleFonts.notoSerif(fontWeight: FontWeight.w600)),
            ),
          ),
        ]);

      case _EmailStep.waitOldCode:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Введите код с текущего email',
            style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _OtpField(controller: _oldCodeCtrl),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _emailLoading ? null : _confirmOldCode,
                child: _emailLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Подтвердить', style: GoogleFonts.notoSerif(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _resetEmailFlow,
              child: Text('Отмена', style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant)),
            ),
          ]),
          if (_resendCooldown > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Повторная отправка через $_resendCooldown с',
              style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ] else ...[
            TextButton(
              onPressed: _requestEmailChange,
              child: Text('Отправить снова', style: GoogleFonts.notoSerif(color: cs.primary, fontSize: 12)),
            ),
          ],
        ]);

      case _EmailStep.waitNewCode:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Введите код с нового email ($_pendingNewEmail)',
            style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _OtpField(controller: _newCodeCtrl),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _emailLoading ? null : _confirmNewCode,
                child: _emailLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Подтвердить', style: GoogleFonts.notoSerif(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _resetEmailFlow,
              child: Text('Отмена', style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant)),
            ),
          ]),
        ]);

      case _EmailStep.done:
        return OutlinedButton.icon(
          onPressed: _resetEmailFlow,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text('Изменить снова', style: GoogleFonts.notoSerif()),
        );
    }
  }
}

enum _EmailStep { idle, waitOldCode, waitNewCode, done }

// ── Appearance card ───────────────────────────────────────────────────────────

class _AppearanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final isDark = themeState.mode == ThemeMode.dark;

    return _SectionCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Внешний вид'),
        const SizedBox(height: 14),
        Text('Тема',
            style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(children: [
          _ThemeChip(
            label: 'Тёмная',
            icon: Icons.dark_mode_rounded,
            selected: isDark,
            onTap: () => notifier.setMode(ThemeMode.dark),
          ),
          const SizedBox(width: 10),
          _ThemeChip(
            label: 'Светлая',
            icon: Icons.light_mode_rounded,
            selected: !isDark,
            onTap: () => notifier.setMode(ThemeMode.light),
          ),
        ]),
        const SizedBox(height: 18),
        Text('Цвет акцента',
            style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(accentOptions.length, (i) {
            final opt = accentOptions[i];
            final selected = themeState.accentIndex == i;
            return GestureDetector(
              onTap: () => notifier.setAccent(i),
              child: Tooltip(
                message: opt.label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: opt.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? cs.onSurface : opt.color.withOpacity(0.2),
                      width: selected ? 2.5 : 1.5,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(
                            color: opt.color.withOpacity(0.45),
                            blurRadius: 8,
                            spreadRadius: 1)]
                        : null,
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          color: Colors.white.withOpacity(0.9), size: 18)
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    ));
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.15) : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.5) : cs.outline,
            width: selected ? 1.3 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.notoSerif(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
        ]),
      ),
    );
  }
}

// ── ShowAllTab toggle ─────────────────────────────────────────────────────────

class _ShowAllTabToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline, width: 0.9),
      ),
      child: Row(children: [
        Icon(Icons.tab_outlined, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Вкладка «Все»',
                style: GoogleFonts.notoSerif(color: cs.onSurface, fontSize: 14)),
            Text('Показывать все стихи отдельной вкладкой',
                style: GoogleFonts.notoSerif(
                    color: cs.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
        Switch(
          value: user.showAllTab,
          onChanged: (v) =>
              ref.read(authProvider.notifier).updateProfile(showAllTab: v),
          activeColor: cs.primary,
        ),
      ]),
    );
  }
}

// ── OTP field ─────────────────────────────────────────────────────────────────

class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  const _OtpField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        color: cs.onSurface, fontSize: 22, letterSpacing: 8,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '······',
        hintStyle: GoogleFonts.playfairDisplay(
          color: cs.onSurfaceVariant.withOpacity(0.4),
          fontSize: 22, letterSpacing: 8,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        filled: true,
        fillColor: cs.surface.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.5), width: 0.8),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(text,
        style: GoogleFonts.playfairDisplay(
          color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600,
        ));
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  const _SettingsField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.notoSerif(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSerif(color: cs.onSurfaceVariant, fontSize: 13),
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        filled: true,
        fillColor: cs.surface.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _StatusMsg extends StatelessWidget {
  final String text;
  final bool isError;
  const _StatusMsg({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isError ? cs.error : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: color, size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: GoogleFonts.notoSerif(color: color, fontSize: 12.5))),
      ]),
    );
  }
}
