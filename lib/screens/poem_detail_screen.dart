// lib/screens/poem_detail_screen.dart
// Исправлено: белый текст "Скопировано" на светлой теме

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poem.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';

class PoemDetailScreen extends ConsumerWidget {
  final Poem poem;
  const PoemDetailScreen({super.key, required this.poem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isRead = user?.readPoems.contains(poem.id) ?? false;
    final isPinned = user?.pinnedPoemId == poem.id;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline, width: 0.8),
            ),
            child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(poem.title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
                color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          _AppBarAction(
            icon: Icons.copy_outlined,
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: '${poem.title}\n${poem.author}\n\n${poem.text}'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Скопировано',
                    style: GoogleFonts.notoSerif(
                        fontSize: 13,
                        // Адаптивный цвет текста
                        color: isDark ? Colors.white : Colors.black87)),
                backgroundColor: cs.surfaceVariant,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            },
          ),
          if (user != null) ...[
            const SizedBox(width: 4),
            _AppBarAction(
              icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              active: isPinned,
              onTap: () => ref.read(authProvider.notifier).togglePin(poem.id),
            ),
            const SizedBox(width: 4),
            _AppBarAction(
              icon: isRead
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              active: isRead,
              onTap: () => ref.read(authProvider.notifier).toggleRead(poem.id),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(poem.author,
              style: GoogleFonts.notoSerif(
                  color: cs.primary, fontSize: 14,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          if (poem.lineCount > 0)
            Text('${poem.lineCount} строк',
                style: GoogleFonts.notoSerif(
                    color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            width: 40, height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withOpacity(0)]),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            poem.text,
            style: GoogleFonts.notoSerif(
                color: cs.onSurface, fontSize: 16, height: 1.95),
          ),

          // Кнопка удалить из библиотеки (в конце стиха)
          _DeleteFromLibraryButton(poem: poem),

          if (user != null && (isRead || isPinned)) ...[
            const SizedBox(height: 28),
            Wrap(spacing: 8, children: [
              if (isRead)
                _StatusChip(
                    icon: Icons.check_rounded,
                    label: 'Прочитано',
                    color: cs.primary),
              if (isPinned)
                _StatusChip(
                    icon: Icons.push_pin_rounded,
                    label: 'Закреплено',
                    color: cs.tertiary),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Кнопка удалить из библиотеки (в конце стиха) ─────────────────────────────

class _DeleteFromLibraryButton extends ConsumerWidget {
  final Poem poem;
  const _DeleteFromLibraryButton({required this.poem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final libState = ref.watch(myLibraryProvider).value;
    if (libState == null) return const SizedBox.shrink();

    // Ищем этот стих в библиотеке
    final entry = libState.poems.where(
      (p) => p.poemId == poem.id || (p.isCustom && p.title == poem.title),
    ).firstOrNull;
    if (entry == null) return const SizedBox.shrink();

    return Column(children: [
      const SizedBox(height: 32),
      const Divider(),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text('Удалить из библиотеки?',
                  style: GoogleFonts.playfairDisplay(
                      fontWeight: FontWeight.w600)),
              content: Text('Стихотворение будет удалено из вашей библиотеки.',
                  style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: cs.error),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await ref.read(myLibraryProvider.notifier).removePoem(entry.id);
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_outline, color: cs.error, size: 18),
          const SizedBox(width: 6),
          Text('Удалить из библиотеки',
              style: GoogleFonts.notoSerif(color: cs.error, fontSize: 14)),
        ]),
      ),
    ]);
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _AppBarAction({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: active ? cs.primary.withOpacity(0.15) : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: active ? cs.primary.withOpacity(0.4) : cs.outline,
              width: 0.8),
        ),
        child: Icon(icon, color: active ? cs.primary : cs.onSurface, size: 18),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.notoSerif(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
