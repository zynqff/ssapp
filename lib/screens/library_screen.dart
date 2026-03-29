// lib/screens/library_screen.dart
// Вкладка "Библиотека" в BottomNav.
// Показывает личную библиотеку пользователя.
// Кнопка "сменить" открывает поиск чужих библиотек.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/library_provider.dart';
import '../models/library.dart';
import 'add_poem_to_library_screen.dart';
import 'library_search_screen.dart';
import 'poem_detail_screen.dart';
import '../models/poem.dart';

// Доступные варианты сортировки
const _sortOptions = [
  ('added', 'По добавлению'),
  ('author', 'По автору'),
  ('length', 'По длине'),
  ('read', 'Прочитанные'),
  ('unread', 'Непрочитанные'),
];

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _sortBy = 'added';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(myLibraryProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(myLibraryProvider.notifier).load(),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
          data: (libState) {
            if (libState == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final poems = ref
                .read(myLibraryProvider.notifier)
                .sortedPoems(sortBy: _sortBy);
            return CustomScrollView(
              slivers: [
                // Заголовок + кнопки
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                libState.library.name,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              if (libState.library.description.isNotEmpty)
                                Text(
                                  libState.library.description,
                                  style: GoogleFonts.notoSerif(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        // Сменить библиотеку
                        IconButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const LibrarySearchScreen()),
                          ),
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: 'Сменить библиотеку',
                        ),
                        // Ещё
                        IconButton(
                          onPressed: () => _showLibraryMenu(context, libState),
                          icon: const Icon(Icons.more_vert),
                        ),
                      ],
                    ),
                  ),
                ),

                // Статус публикации
                if (libState.library.status != 'pending')
                  SliverToBoxAdapter(
                    child: _StatusBanner(library: libState.library),
                  ),

                // Сортировка + счётчик
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '${poems.length} стихов',
                          style: GoogleFonts.notoSerif(
                              fontSize: 13,
                              color: cs.onSurfaceVariant),
                        ),
                        const Spacer(),
                        _SortDropdown(
                          value: _sortBy,
                          onChanged: (v) =>
                              setState(() => _sortBy = v),
                        ),
                      ],
                    ),
                  ),
                ),

                // Список стихов
                poems.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.collections_bookmark_outlined,
                                  size: 64,
                                  color: cs.onSurfaceVariant
                                      .withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'Библиотека пуста',
                                style: GoogleFonts.notoSerif(
                                    color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Добавь стихи из каталога или свои',
                                style: GoogleFonts.notoSerif(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant
                                        .withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _LibraryPoemTile(
                            poem: poems[i],
                            onToggleRead: () => ref
                                .read(myLibraryProvider.notifier)
                                .toggleRead(poems[i].id),
                            onRemove: () async {
                              final err = await ref
                                  .read(myLibraryProvider.notifier)
                                  .removePoem(poems[i].id);
                              if (context.mounted && err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)));
                              }
                            },
                            onTap: () {
                              // Открываем стих — либо из общей БД либо кастомный
                              final p = Poem(
                                id: poems[i].poemId ?? 0,
                                title: poems[i].title,
                                author: poems[i].author,
                                text: poems[i].text,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PoemDetailScreen(poem: p)),
                              );
                            },
                          ),
                          childCount: poems.length,
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
      // FAB — добавить стих
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AddPoemToLibraryScreen()),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showLibraryMenu(BuildContext context, LibraryState libState) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, libState);
              },
            ),
            if (libState.library.status != 'published')
              ListTile(
                leading: const Icon(Icons.publish_outlined),
                title: const Text('Опубликовать'),
                onTap: () {
                  Navigator.pop(context);
                  _publishLibrary(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, LibraryState libState) {
    final ctrl = TextEditingController(text: libState.library.name);
    final descCtrl =
        TextEditingController(text: libState.library.description);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Название')),
            const SizedBox(height: 8),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(myLibraryProvider.notifier)
                  .updateInfo(ctrl.text.trim(), descCtrl.text.trim());
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _publishLibrary(BuildContext context) async {
    final result =
        await ref.read(myLibraryProvider.notifier).publish();
    if (!context.mounted) return;
    final msg = result.error ??
        (result.status == 'published'
            ? 'Библиотека опубликована!'
            : 'Отправлена на модерацию');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Статус-баннер ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final UserLibrary library;
  const _StatusBanner({required this.library});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (library.status == 'published') return const SizedBox.shrink();

    final isRejected = library.status == 'rejected';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRejected
              ? cs.errorContainer
              : cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
              size: 18,
              color: isRejected ? cs.error : cs.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRejected
                    ? 'Отклонено: ${library.rejectReason}'
                    : 'На модерации — ожидай одобрения',
                style: GoogleFonts.notoSerif(
                  fontSize: 13,
                  color: isRejected ? cs.onErrorContainer : cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Дропдаун сортировки ───────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      icon: Icon(Icons.sort, size: 18, color: cs.primary),
      style: GoogleFonts.notoSerif(fontSize: 13, color: cs.onSurface),
      items: _sortOptions
          .map((o) =>
              DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── Тайл стиха в библиотеке ───────────────────────────────────────────────────

class _LibraryPoemTile extends StatelessWidget {
  final LibraryPoem poem;
  final VoidCallback onToggleRead;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _LibraryPoemTile({
    required this.poem,
    required this.onToggleRead,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (poem.isCustom)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.edit_note,
                                  size: 14, color: cs.primary),
                            ),
                          Expanded(
                            child: Text(
                              poem.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: poem.isRead
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                                decoration: poem.isRead
                                    ? TextDecoration.none
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        poem.author,
                        style: GoogleFonts.notoSerif(
                            fontSize: 12, color: cs.primary),
                      ),
                    ],
                  ),
                ),
                // Прочитано
                IconButton(
                  icon: Icon(
                    poem.isRead
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        poem.isRead ? cs.primary : cs.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: onToggleRead,
                ),
                // Удалить
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: cs.onSurfaceVariant, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
