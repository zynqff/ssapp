import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/poems_provider.dart';
import '../providers/theme_provider.dart';
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

  Future<void> _save(bool currentShowAllTab) async {
    setState(() { _loading = true; _error = null; _success = null; });
    final err = await ref.read(authProvider.notifier).updateProfile(
      newPassword: _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
      userData: _bioCtrl.text,
      showAllTab: currentShowAllTab,
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
            child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Профиль',
            style: GoogleFonts.playfairDisplay(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            )),
      ),
      body: userAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
        error: (_, __) => const SizedBox.shrink(),
        data: (user) {
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.person_outline_rounded,
                        size: 36, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Text('Вы не вошли в аккаунт',
                      style: GoogleFonts.notoSerif(
                          color: cs.onSurfaceVariant, fontSize: 14)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    icon: const Icon(Icons.login_rounded),
                    label: Text('Войти',
                        style: GoogleFonts.notoSerif(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [

              // ── Profile card ──────────────────────────────────────────
              _SectionCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          user.username[0].toUpperCase(),
                          style: GoogleFonts.playfairDisplay(
                            color: cs.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(user.username,
                        style: GoogleFonts.playfairDisplay(
                          color: cs.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        )),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: cs.outline.withOpacity(0.4), height: 1),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                    _Stat(label: 'Прочитано', value: '$readCount'),
                    _Divider(),
                    _Stat(label: 'Всего', value: '$total'),
                    _Divider(),
                    _Stat(label: 'Прогресс', value: '$pct%'),
                  ]),
                  if (user.pinnedPoemId != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: cs.outline.withOpacity(0.4), height: 1),
                    ),
                    Row(children: [
                      Icon(Icons.push_pin_rounded, size: 13, color: cs.tertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        'Закреплено: ${poems.where((p) => p.id == user.pinnedPoemId).firstOrNull?.title ?? "#${user.pinnedPoemId}"}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSerif(
                            color: cs.onSurfaceVariant, fontSize: 12.5),
                      )),
                    ]),
                  ],
                ],
              )),
              const SizedBox(height: 12),

              // ── Appearance ────────────────────────────────────────────
              _AppearanceCard(),
              const SizedBox(height: 12),

              // ── Account settings ──────────────────────────────────────
              _SectionCard(child: Builder(builder: (context) {
                final showAll = user.showAllTab;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Настройки аккаунта'),
                    const SizedBox(height: 14),
                    _ProfileField(
                      controller: _passCtrl,
                      label: 'Новый пароль',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    _ProfileField(
                      controller: _bioCtrl,
                      label: 'О себе',
                      icon: Icons.info_outline_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    // ── Переключатель вкладки «Все» ──────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: cs.outline, width: 0.9),
                      ),
                      child: Row(children: [
                        Icon(Icons.tab_outlined,
                            size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Вкладка «Все»',
                                  style: GoogleFonts.notoSerif(
                                      color: cs.onSurface,
                                      fontSize: 14)),
                              Text('Показывать все стихи отдельной вкладкой',
                                  style: GoogleFonts.notoSerif(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: showAll,
                          onChanged: _loading
                              ? null
                              : (v) => ref
                                  .read(authProvider.notifier)
                                  .updateProfile(showAllTab: v),
                          activeColor: cs.primary,
                        ),
                      ]),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _StatusMsg(text: _error!, isError: true),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: 10),
                      _StatusMsg(text: _success!, isError: false),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _loading ? null : () => _save(showAll),
                        child: Text('Сохранить',
                            style: GoogleFonts.notoSerif(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ],
                );
              })),
              const SizedBox(height: 12),

              // ── AI key ────────────────────────────────────────────────
              _SectionCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Доступ к AI'),
                  const SizedBox(height: 4),
                  Text(
                    'Введи ключ от администратора для использования AI-чата',
                    style: GoogleFonts.notoSerif(
                        color: cs.onSurfaceVariant, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _ProfileField(
                        controller: _keyCtrl,
                        label: 'Ключ доступа',
                        icon: Icons.vpn_key_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _loading ? null : _verifyKey,
                        child: Text('OK',
                            style: GoogleFonts.notoSerif(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ],
              )),
              const SizedBox(height: 20),

              // ── Logout ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: Icon(Icons.logout_rounded,
                      color: cs.error, size: 18),
                  label: Text('Выйти',
                      style: GoogleFonts.notoSerif(
                          color: cs.error,
                          fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: cs.error.withOpacity(0.4), width: 0.9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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

        // Label
        Text('Тема',
            style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant, fontSize: 12,
                letterSpacing: 0.5)),
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
                color: cs.onSurfaceVariant, fontSize: 12,
                letterSpacing: 0.5)),
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
                      color: selected
                          ? cs.onSurface
                          : opt.color.withOpacity(0.2),
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
  const _ThemeChip({required this.label, required this.icon,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.15)
              : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.5) : cs.outline,
            width: selected ? 1.3 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16,
              color: selected ? cs.primary : cs.onSurfaceVariant),
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
          color: cs.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ));
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final int maxLines;
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      style: GoogleFonts.notoSerif(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSerif(
            color: cs.onSurfaceVariant, fontSize: 13),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: color, size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: GoogleFonts.notoSerif(color: color, fontSize: 12.5))),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Text(value,
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          )),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.notoSerif(
              color: cs.onSurfaceVariant, fontSize: 11.5)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
        width: 1, height: 32, color: cs.outline.withOpacity(0.4));
  }
}
