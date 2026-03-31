// lib/screens/library_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/library_provider.dart';
import '../providers/auth_provider.dart';
import '../models/library.dart';
import '../models/poem.dart';
import 'add_poem_to_library_screen.dart';
import 'library_search_screen.dart';
import 'poem_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibrarySortBy _sortBy = LibrarySortBy.added;
  SortDir _dir = SortDir.asc;
  final Set<int> _selected = {};
  bool _selectionMode = false;

  void _toggleSort(LibrarySortBy newSort) {
    setState(() {
      if (_sortBy == newSort) {
        _dir = _dir == SortDir.asc ? SortDir.desc : SortDir.asc;
      } else {
        _sortBy = newSort;
        _dir = SortDir.asc;
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(myLibraryProvider);
    final notifier = ref.read(myLibraryProvider.notifier);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48,
                    color: cs.onSurfaceVariant.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSerif(
                        color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => notifier.load(),
                  child: const Text('Повторить'),
                ),
              ]),
            ),
          ),
          data: (libState) {
            if (libState == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final poems = notifier.sorted(
              sortBy: _sortBy,
              dir: _dir,
              filterRead: _sortBy == LibrarySortBy.read,
              filterUnread: _sortBy == LibrarySortBy.unread,
            );
            return Column(children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(libState.library.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26, fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        )),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LibrarySearchScreen())),
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: 'Сменить библиотеку',
                  ),
                  IconButton(
                    onPressed: () => _showLibraryMenu(context, libState),
                    icon: const Icon(Icons.more_vert),
                  ),
                ]),
              ),

              // Статус
              if (libState.library.status != 'pending')
                _StatusBanner(library: libState.library),

              // Панель выделения
              if (_selectionMode)
                _SelectionBar(
                  count: _selected.length,
                  onDelete: () => _deleteSelected(context),
                  onMarkRead: () => _markSelectedRead(true),
                  onMarkUnread: () => _markSelectedRead(false),
                  onCancel: _exitSelection,
                )
              else
                // Счётчик + сортировка
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
                  child: Row(children: [
                    Text('${poems.length} стихов',
                        style: GoogleFonts.notoSerif(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                    const Spacer(),
                    _SortButton(
                      current: _sortBy,
                      dir: _dir,
                      onSelect: _toggleSort,
                    ),
                  ]),
                ),

              // Список
              Expanded(
                child: poems.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.collections_bookmark_outlined,
                              size: 64,
                              color: cs.onSurfaceVariant.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('Библиотека пуста',
                              style: GoogleFonts.notoSerif(
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('Добавь стихи из каталога или свои',
                              style: GoogleFonts.notoSerif(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant.withOpacity(0.6))),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: poems.length,
                        itemBuilder: (ctx, i) => _LibraryPoemCard(
                          poem: poems[i],
                          isSelected: _selected.contains(poems[i].id),
                          selectionMode: _selectionMode,
                          onTap: () {
                            if (_selectionMode) {
                              setState(() {
                                if (_selected.contains(poems[i].id)) {
                                  _selected.remove(poems[i].id);
                                  if (_selected.isEmpty) _selectionMode = false;
                                } else {
                                  _selected.add(poems[i].id);
                                }
                              });
                            } else {
                              final p = Poem(
                                id: poems[i].poemId ?? 0,
                                title: poems[i].title,
                                author: poems[i].author,
                                text: poems[i].text,
                                lineCount: poems[i].lineCount,
                              );
                              Navigator.push(ctx, MaterialPageRoute(
                                  builder: (_) => PoemDetailScreen(poem: p)));
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _selectionMode = true;
                              _selected.add(poems[i].id);
                            });
                          },
                          onToggleRead: () => notifier.toggleRead(poems[i].id),
                          onTogglePin: () async {
                            final err = await notifier.togglePin(poems[i].id);
                            if (err != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err)));
                            }
                          },
                        ),
                      ),
              ),
            ]);
          },
        ),
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AddPoemToLibraryScreen())),
              backgroundColor: cs.primary,
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Удалить ${_selected.length} стих(а)?',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
        content: Text('Это действие нельзя отменить.',
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
    if (confirmed == true && mounted) {
      await ref.read(myLibraryProvider.notifier).removePoems(_selected.toList());
      _exitSelection();
    }
  }

  Future<void> _markSelectedRead(bool read) async {
    for (final id in _selected) {
      final poem = ref.read(myLibraryProvider).value?.poems
          .firstWhere((p) => p.id == id, orElse: () => throw Exception());
      if (poem == null) continue;
      if (poem.isRead != read) {
        await ref.read(myLibraryProvider.notifier).toggleRead(id);
      }
    }
    _exitSelection();
  }

  void _showLibraryMenu(BuildContext context, LibraryState libState) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 40, height: 4,
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
          if (libState.library.status == 'published')
            ListTile(
              leading: Icon(Icons.unpublished_outlined, color: cs.error),
              title: Text('Снять с публикации', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(context);
                _unpublishLibrary(context);
              },
            ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text('Удалить библиотеку', style: TextStyle(color: cs.error)),
            onTap: () {
              Navigator.pop(context);
              _deleteLibrary(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, LibraryState libState) {
    final nameCtrl = TextEditingController(text: libState.library.name);
    final descCtrl = TextEditingController(text: libState.library.description);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название')),
          const SizedBox(height: 8),
          TextField(controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 2),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(myLibraryProvider.notifier)
                  .updateInfo(nameCtrl.text.trim(), descCtrl.text.trim());
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _publishLibrary(BuildContext context) async {
    final result = await ref.read(myLibraryProvider.notifier).publish();
    if (!mounted) return;
    final msg = result.error ??
        (result.status == 'published'
            ? 'Библиотека опубликована!'
            : 'Отправлена на модерацию');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _unpublishLibrary(BuildContext context) async {
    final err = await ref.read(myLibraryProvider.notifier)
        .updateInfo(
          ref.read(myLibraryProvider).value?.library.name ?? 'Моя библиотека',
          ref.read(myLibraryProvider).value?.library.description ?? '',
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Снято с публикации')));
  }

  void _deleteLibrary(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Удалить библиотеку?',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
        content: Text(
            'Все стихи будут удалены. Это действие нельзя отменить.',
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
    if (confirmed == true && mounted) {
      final err = await ref.read(myLibraryProvider.notifier).deleteLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err ?? 'Библиотека удалена')));
      }
    }
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
          color: isRejected ? cs.errorContainer : cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
              size: 18,
              color: isRejected ? cs.error : cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            isRejected
                ? 'Отклонено: ${library.rejectReason}'
                : 'На модерации — ожидай одобрения',
            style: GoogleFonts.notoSerif(
                fontSize: 13,
                color: isRejected ? cs.onErrorContainer : cs.primary),
          )),
        ]),
      ),
    );
  }
}

// ── Панель выделения ──────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkUnread;
  final VoidCallback onCancel;
  const _SelectionBar({
    required this.count,
    required this.onDelete,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text('Выбрано: $count',
            style: GoogleFonts.notoSerif(color: cs.primary, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.check_circle_outline, color: cs.primary, size: 22),
          tooltip: 'Отметить прочитанными',
          onPressed: onMarkRead,
        ),
        IconButton(
          icon: Icon(Icons.radio_button_unchecked, color: cs.primary, size: 22),
          tooltip: 'Отметить непрочитанными',
          onPressed: onMarkUnread,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error, size: 22),
          tooltip: 'Удалить',
          onPressed: onDelete,
        ),
        IconButton(
          icon: Icon(Icons.close, color: cs.onSurfaceVariant, size: 22),
          onPressed: onCancel,
        ),
      ]),
    );
  }
}

// ── Кнопка сортировки ─────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final LibrarySortBy current;
  final SortDir dir;
  final void Function(LibrarySortBy) onSelect;
  const _SortButton({required this.current, required this.dir, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<LibrarySortBy>(
      onSelected: onSelect,
      icon: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(current.label,
            style: GoogleFonts.notoSerif(fontSize: 13, color: cs.primary)),
        const SizedBox(width: 4),
        Icon(
          dir == SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14, color: cs.primary,
        ),
      ]),
      itemBuilder: (_) => LibrarySortBy.values.map((s) =>
        PopupMenuItem(
          value: s,
          child: Row(children: [
            if (s == current)
              Icon(dir == SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14, color: cs.primary)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 8),
            Text(s.label),
          ]),
        ),
      ).toList(),
    );
  }
}

// ── Карточка стиха в библиотеке ───────────────────────────────────────────────

class _LibraryPoemCard extends StatelessWidget {
  final LibraryPoem poem;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleRead;
  final VoidCallback onTogglePin;

  const _LibraryPoemCard({
    required this.poem,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleRead,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
            ? cs.primary.withOpacity(0.12)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? cs.primary.withOpacity(0.4)
                    : cs.outlineVariant,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Пин-иконка если закреплён
              if (poem.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Icon(Icons.push_pin_rounded,
                      size: 13, color: cs.primary),
                ),
              // Контент
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(poem.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 2),
                  Text(poem.author,
                      style: GoogleFonts.notoSerif(
                          fontSize: 12, color: cs.primary)),
                  if (poem.preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(poem.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSerif(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        )),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              // Правая колонка: кружок прочитан + строки
              Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                selectionMode
                    ? Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        size: 24,
                      )
                    : GestureDetector(
                        onTap: onToggleRead,
                        child: Icon(
                          poem.isRead
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: poem.isRead ? cs.primary : cs.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                const SizedBox(height: 4),
                Text('${poem.lineCount} стр.',
                    style: GoogleFonts.notoSerif(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
