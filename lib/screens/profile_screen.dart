// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/poems_provider.dart';
import '../providers/library_provider.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final globalPoems = ref.watch(poemsProvider).value ?? [];
    final libAsync = ref.watch(myLibraryProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Профиль',
            style: GoogleFonts.playfairDisplay(
                color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: userAsync.when(
        // ── Загрузка: показываем скелетон вместо спиннера чтобы не было серого экрана
        loading: () => _buildSkeleton(cs),
        error: (_, __) => const SizedBox.shrink(),
        data: (user) {
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(22)),
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

          // Статистика — берём из библиотеки если загружена, иначе из auth (офлайн данные)
          final libState = libAsync.valueOrNull;
          final libLoaded = libAsync is AsyncData;

          int readCount;
          int total;
          int pct;
          String? libName;

          if (libLoaded && libState != null) {
            total = libState.poems.length;
            readCount = libState.poems.where((p) => p.isRead).length;
            pct = total > 0 ? ((readCount / total) * 100).round() : 0;
            libName = libState.library.name;
          } else {
            // Офлайн или библиотека ещё не загружена — глобальные данные из кеша auth
            readCount = user.readPoems.length;
            total = globalPoems.length;
            pct = total > 0 ? ((readCount / total) * 100).round() : 0;
            libName = null;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SectionCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16)),
                      child: Center(child: Text(
                        user.username[0].toUpperCase(),
                        style: GoogleFonts.playfairDisplay(
                            color: cs.primary, fontSize: 22,
                            fontWeight: FontWeight.w600),
                      )),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.username,
                              style: GoogleFonts.playfairDisplay(
                                  color: cs.onSurface, fontSize: 20,
                                  fontWeight: FontWeight.w600)),
                          // Индикатор офлайн режима
                          if (!libLoaded)
                            Row(children: [
                              Icon(Icons.wifi_off_rounded,
                                  size: 11, color: cs.onSurfaceVariant.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Text('офлайн',
                                  style: GoogleFonts.notoSerif(
                                      color: cs.onSurfaceVariant.withOpacity(0.5),
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                            ]),
                        ],
                      ),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: cs.outline.withOpacity(0.4), height: 1),
                  ),
                  if (libName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(Icons.collections_bookmark_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Прогресс по: $libName',
                            style: GoogleFonts.notoSerif(
                                fontSize: 12, color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic)),
                      ]),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: 'Прочитано', value: '$readCount'),
                      _VertDivider(),
                      _Stat(label: 'Всего', value: '$total'),
                      _VertDivider(),
                      _Stat(label: 'Прогресс', value: '$pct%'),
                    ],
                  ),
                  // Закреплённый стих
                  Builder(builder: (context) {
                    String? pinnedTitle;
                    final pinned =
                        libState?.poems.where((p) => p.isPinned).toList() ?? [];
                    if (pinned.isNotEmpty) {
                      pinnedTitle = pinned.first.title;
                    } else if (user.pinnedPoemId != null) {
                      pinnedTitle = globalPoems
                              .where((p) => p.id == user.pinnedPoemId)
                              .firstOrNull
                              ?.title ??
                          '#${user.pinnedPoemId}';
                    }
                    if (pinnedTitle == null) return const SizedBox.shrink();
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(color: cs.outline.withOpacity(0.4), height: 1),
                      ),
                      Row(children: [
                        Icon(Icons.push_pin_rounded, size: 13, color: cs.tertiary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Закреплено: $pinnedTitle',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSerif(
                              color: cs.onSurfaceVariant, fontSize: 12.5),
                        )),
                      ]),
                    ]);
                  }),
                ],
              )),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text('Настройки',
                      style: GoogleFonts.notoSerif(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, ref),
                  icon: Icon(Icons.logout_rounded, color: cs.error, size: 18),
                  label: Text('Выйти',
                      style: GoogleFonts.notoSerif(
                          color: cs.error, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.error.withOpacity(0.4), width: 0.9),
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

  // Скелетон вместо серого экрана — показывает структуру пока грузится auth
  Widget _buildSkeleton(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outline.withOpacity(0.5), width: 0.8),
          ),
          child: Column(children: [
            Row(children: [
              _SkeletonBox(width: 52, height: 52, radius: 16),
              const SizedBox(width: 14),
              _SkeletonBox(width: 120, height: 20, radius: 6),
            ]),
            const SizedBox(height: 16),
            Divider(color: cs.outline.withOpacity(0.4), height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SkeletonBox(width: 50, height: 40, radius: 6),
                _SkeletonBox(width: 50, height: 40, radius: 6),
                _SkeletonBox(width: 50, height: 40, radius: 6),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _SkeletonBox(width: double.infinity, height: 48, radius: 14),
        const SizedBox(height: 10),
        _SkeletonBox(width: double.infinity, height: 48, radius: 14),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outline.withOpacity(0.5), width: 0.8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: cs.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.logout_rounded, color: cs.error, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Выход из аккаунта',
                    style: GoogleFonts.playfairDisplay(
                        color: cs.onSurface, fontSize: 17,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Ты точно хочешь выйти из аккаунта?',
                  style: GoogleFonts.notoSerif(
                      color: cs.onSurfaceVariant, fontSize: 14, height: 1.6)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.outline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text('Отмена',
                      style: GoogleFonts.notoSerif(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                )),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text('Выйти',
                      style: GoogleFonts.notoSerif(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _SkeletonBox(
      {required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.outline.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

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

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Text(value,
          style: GoogleFonts.playfairDisplay(
              color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.notoSerif(
              color: cs.onSurfaceVariant, fontSize: 11.5)),
    ]);
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(width: 1, height: 32, color: cs.outline.withOpacity(0.4));
  }
}
