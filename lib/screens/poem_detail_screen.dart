import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(poem.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Скопировать',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${poem.title}\n${poem.author}\n\n${poem.text}'));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано')));
            },
          ),
          if (user != null) ...[
            IconButton(
              icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: isPinned ? 'Открепить' : 'Закрепить',
              onPressed: () =>
                  ref.read(authProvider.notifier).togglePin(poem.title),
            ),
            IconButton(
              icon: Icon(isRead ? Icons.check_circle : Icons.check_circle_outline),
              tooltip: isRead ? 'Снять отметку' : 'Отметить прочитанным',
              onPressed: () =>
                  ref.read(authProvider.notifier).toggleRead(poem.title),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(poem.author,
              style: t.textTheme.titleMedium?.copyWith(
                  color: t.colorScheme.primary, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Text('${poem.lineCount} строк',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const Divider(height: 32),
          SelectableText(poem.text,
              style: t.textTheme.bodyLarge?.copyWith(height: 1.9)),
          const SizedBox(height: 32),
          if (user != null)
            Wrap(spacing: 8, children: [
              if (isRead)
                Chip(
                  avatar: Icon(Icons.check, size: 14,
                      color: t.colorScheme.onSecondaryContainer),
                  label: const Text('Прочитано'),
                  backgroundColor: t.colorScheme.secondaryContainer,
                ),
              if (isPinned)
                Chip(
                  avatar: Icon(Icons.push_pin, size: 14,
                      color: t.colorScheme.onTertiaryContainer),
                  label: const Text('Закреплено'),
                  backgroundColor: t.colorScheme.tertiaryContainer,
                ),
            ]),
        ]),
      ),
    );
  }
}
