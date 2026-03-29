// lib/screens/library_detail_screen.dart
// Просмотр публичной библиотеки — стихи, лайк, сохранение.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/library.dart';
import '../models/poem.dart';
import '../services/api_service.dart';
import 'poem_detail_screen.dart';

class LibraryDetailScreen extends ConsumerStatefulWidget {
  final int libraryId;
  const LibraryDetailScreen({super.key, required this.libraryId});

  @override
  ConsumerState<LibraryDetailScreen> createState() =>
      _LibraryDetailScreenState();
}

class _LibraryDetailScreenState
    extends ConsumerState<LibraryDetailScreen> {
  LibraryState? _state;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService().getLibrary(widget.libraryId);
    if (mounted) {
      setState(() {
        _state = data != null ? LibraryState.fromJson(data) : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: cs.surface),
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_state == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: cs.surface),
        backgroundColor: cs.surface,
        body: Center(
            child: Text('Библиотека не найдена',
                style: GoogleFonts.notoSerif())),
      );
    }

    final lib = _state!.library;
    final poems = _state!.poems;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: cs.surface,
            pinned: true,
            title: Text(lib.name,
                style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w600)),
            actions: [
              // Лайк
              IconButton(
                icon: Icon(
                  _state!.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _state!.isLiked ? Colors.red : null,
                ),
                onPressed: _toggleLike,
              ),
              // Сохранить
              if (!_state!.isSaved)
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: _saveLibrary,
                  tooltip: 'Сохранить библиотеку',
                )
              else
                IconButton(
                  icon: Icon(Icons.bookmark, color: cs.primary),
                  onPressed: _unsaveLibrary,
                  tooltip: 'Убрать из сохранённых',
                ),
            ],
          ),

          // Мета
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Автор: ${lib.owner}',
                    style: GoogleFonts.notoSerif(
                        fontSize: 13, color: cs.primary),
                  ),
                  if (lib.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(lib.description,
                        style: GoogleFonts.notoSerif(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.favorite_outline,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${lib.likesCount}',
                          style: GoogleFonts.notoSerif(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 16),
                      Icon(Icons.collections_bookmark_outlined,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${poems.length} стихов',
                          style: GoogleFonts.notoSerif(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),

                  // Кнопка "поставить по умолчанию"
                  if (_state!.isSaved) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _setDefault,
                      icon: const Icon(Icons.home_outlined, size: 16),
                      label: const Text('Сделать основной'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Стихи
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final p = poems[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: ListTile(
                      title: Text(p.title,
                          style: GoogleFonts.playfairDisplay(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      subtitle: Text(p.author,
                          style: GoogleFonts.notoSerif(
                              fontSize: 12, color: cs.primary)),
                      trailing: p.isCustom
                          ? Icon(Icons.edit_note,
                              size: 16, color: cs.onSurfaceVariant)
                          : null,
                      onTap: () {
                        final poem = Poem(
                          id: p.poemId ?? 0,
                          title: p.title,
                          author: p.author,
                          text: p.text,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PoemDetailScreen(poem: poem)),
                        );
                      },
                    ),
                  ),
                );
              },
              childCount: poems.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    final res = await ApiService().toggleLibraryLike(widget.libraryId);
    if (res != null && mounted) {
      setState(() {
        final liked = res['action'] == 'liked';
        final count = (res['likes_count'] as num).toInt();
        _state = _state!.copyWith(
          isLiked: liked,
          library: UserLibrary(
            id: _state!.library.id,
            owner: _state!.library.owner,
            name: _state!.library.name,
            description: _state!.library.description,
            status: _state!.library.status,
            rejectReason: _state!.library.rejectReason,
            likesCount: count,
            savesCount: _state!.library.savesCount,
          ),
        );
      });
    }
  }

  Future<void> _saveLibrary() async {
    final err = await ApiService().saveLibrary(widget.libraryId);
    if (mounted) {
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      } else {
        setState(() => _state = _state!.copyWith(isSaved: true));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Библиотека сохранена')),
        );
      }
    }
  }

  Future<void> _unsaveLibrary() async {
    await ApiService().unsaveLibrary(widget.libraryId);
    if (mounted) {
      setState(() => _state = _state!.copyWith(isSaved: false));
    }
  }

  Future<void> _setDefault() async {
    final err =
        await ApiService().setDefaultLibrary(widget.libraryId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Библиотека установлена по умолчанию')));
    }
  }
}
