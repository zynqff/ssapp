import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poem.dart';

class PoemCard extends StatelessWidget {
  final Poem poem;
  final bool isRead;
  final bool isPinned;
  final VoidCallback onTap;

  const PoemCard({
    super.key,
    required this.poem,
    required this.isRead,
    required this.isPinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card gradient adapts to light/dark
    final cardTop = isDark ? const Color(0xFF2A2A42) : const Color(0xFFFFFFFF);
    final cardBot = isDark ? const Color(0xFF222236) : const Color(0xFFF8F6FF);
    final borderCol = isDark ? const Color(0xFF3C3C58) : const Color(0xFFDDDAEE);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: cs.primary.withOpacity(0.08),
          highlightColor: cs.primary.withOpacity(0.04),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cardTop, cardBot],
              ),
              border: Border.all(color: borderCol, width: 0.9),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: title / author / preview ───────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (isPinned) ...[
                            Icon(Icons.push_pin_rounded,
                                size: 14, color: cs.tertiary),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              poem.title,
                              style: GoogleFonts.playfairDisplay(
                                color: cs.onSurface,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(
                          poem.author,
                          style: GoogleFonts.notoSerif(
                            color: cs.primary,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          poem.text.split('\n').take(2).join('\n'),
                          style: GoogleFonts.notoSerif(
                            color: cs.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Right: read badge + line count ───────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRead
                              ? cs.primary.withOpacity(0.18)
                              : Colors.transparent,
                          border: isRead
                              ? null
                              : Border.all(
                                  color: cs.onSurfaceVariant.withOpacity(0.5),
                                  width: 1.5,
                                ),
                        ),
                        child: isRead
                            ? Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: cs.primary,
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${poem.lineCount} стр.',
                        style: GoogleFonts.notoSerif(
                          color: cs.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
