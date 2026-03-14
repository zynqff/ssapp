import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poem.dart';
import '../providers/auth_provider.dart';

class PoemDetailScreen extends ConsumerWidget {
  final Poem poem;
  const PoemDetailScreen({super.key, required this.poem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isRead = user?.readPoems.contains(poem.title) ?? false;
    final isPinned = user?.pinnedPoemTitle == poem.title;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          poem.title,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _AppBarAction(
            icon: Icons.copy_outlined,
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: '${poem.title}\n${poem.author}\n\n${poem.text}'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Скопировано',
                    style: GoogleFonts.notoSerif(fontSize: 13)),
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
              icon: isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              active: isPinned,
              onTap: () =>
                  ref.read(authProvider.notifier).togglePin(poem.title),
            ),
            const SizedBox(width: 4),
            _AppBarAction(
              icon: isRead
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              active: isRead,
              onTap: () =>
                  ref.read(authProvider.notifier).toggleRead(poem.title),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author + meta
            Text(
              poem.author,
              style: GoogleFonts.notoSerif(
                color: cs.primary,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${poem.lineCount} строк',
              style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),

            // Decorative divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(children: [
                Container(
                    width: 32,
                    height: 1.5,
                    color: cs.primary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.5),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(
                        height: 0.8,
                        color: cs.outline.withOpacity(0.4))),
              ]),
            ),

            // Poem text
            SelectableText(
              poem.text,
              style: GoogleFonts.notoSerif(
                color: cs.onSurface,
                fontSize: 16,
                height: 1.95,
              ),
            ),

            // Status chips
            if (user != null && (isRead || isPinned)) ...[
              const SizedBox(height: 28),
              Wrap(spacing: 8, children: [
                if (isRead)
                  _StatusChip(
                    icon: Icons.check_rounded,
                    label: 'Прочитано',
                    color: cs.primary,
                  ),
                if (isPinned)
                  _StatusChip(
                    icon: Icons.push_pin_rounded,
                    label: 'Закреплено',
                    color: cs.tertiary,
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _AppBarAction({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withOpacity(0.15)
              : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? cs.primary.withOpacity(0.4) : cs.outline,
            width: 0.8,
          ),
        ),
        child: Icon(icon,
            color: active ? cs.primary : cs.onSurface, size: 18),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip(
      {required this.icon, required this.label, required this.color});

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
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
