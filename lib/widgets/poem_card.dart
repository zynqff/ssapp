import 'package:flutter/material.dart';
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
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (isPinned) ...[
                        Icon(Icons.push_pin, size: 14, color: t.colorScheme.tertiary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          poem.title,
                          style: t.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isRead ? TextDecoration.lineThrough : null,
                            color: isRead ? t.colorScheme.onSurfaceVariant : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(poem.author,
                        style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.primary,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text(
                      poem.text.split('\n').take(2).join('\n'),
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Icon(
                  isRead ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: isRead ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text('${poem.lineCount} стр.',
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
