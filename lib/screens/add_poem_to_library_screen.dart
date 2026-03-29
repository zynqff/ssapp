// lib/screens/add_poem_to_library_screen.dart
// Экран добавления стиха в личную библиотеку.
// Два режима: из каталога (поиск) или свой (форма).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/library_provider.dart';
import '../providers/poems_provider.dart';
import '../models/poem.dart';

class AddPoemToLibraryScreen extends ConsumerStatefulWidget {
  const AddPoemToLibraryScreen({super.key});

  @override
  ConsumerState<AddPoemToLibraryScreen> createState() =>
      _AddPoemToLibraryScreenState();
}

class _AddPoemToLibraryScreenState
    extends ConsumerState<AddPoemToLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Форма кастомного стиха
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text('Добавить стих',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Из каталога'),
            Tab(text: 'Свой стих'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildCatalogTab(cs),
          _buildCustomTab(cs),
        ],
      ),
    );
  }

  // ── Из каталога ──────────────────────────────────────────────────────────

  Widget _buildCatalogTab(ColorScheme cs) {
    final poemsState = ref.watch(poemsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Поиск по названию или автору',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: poemsState.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Ошибка загрузки')),
            data: (poems) {
              final filtered = _query.isEmpty
                  ? poems
                  : poems
                      .where((p) =>
                          p.title.toLowerCase().contains(_query) ||
                          p.author.toLowerCase().contains(_query))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('Ничего не найдено',
                      style: GoogleFonts.notoSerif(
                          color: cs.onSurfaceVariant)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) =>
                    _CatalogPoemTile(poem: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Свой стих ─────────────────────────────────────────────────────────────

  Widget _buildCustomTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Добавь любимый стих вручную',
            style: GoogleFonts.notoSerif(
                fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorCtrl,
            decoration: InputDecoration(
              labelText: 'Автор',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            decoration: InputDecoration(
              labelText: 'Текст стихотворения',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 10,
            minLines: 6,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: GoogleFonts.notoSerif(
                    color: cs.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _saveCustom,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Добавить в библиотеку'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCustom() async {
    final title = _titleCtrl.text.trim();
    final author = _authorCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (title.isEmpty || author.isEmpty || text.isEmpty) {
      setState(() => _error = 'Заполни все поля');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final err = await ref.read(myLibraryProvider.notifier).addCustomPoem(
          title: title,
          author: author,
          text: text,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() { _saving = false; _error = err; });
    } else {
      Navigator.pop(context);
    }
  }
}

// ── Тайл стиха из каталога ────────────────────────────────────────────────────

class _CatalogPoemTile extends ConsumerWidget {
  final Poem poem;
  const _CatalogPoemTile({required this.poem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(poem.title,
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(poem.author,
            style:
                GoogleFonts.notoSerif(fontSize: 12, color: cs.primary)),
        trailing: IconButton(
          icon: Icon(Icons.add_circle_outline, color: cs.primary),
          onPressed: () async {
            final err = await ref
                .read(myLibraryProvider.notifier)
                .addPoem(poem.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err ?? 'Добавлено!'),
                behavior: SnackBarBehavior.floating,
              ));
              if (err == null) Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
}
