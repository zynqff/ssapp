// lib/screens/library_search_screen.dart
// Поиск опубликованных библиотек + возможность сохранить/поставить дефолтной.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/library.dart';
import '../services/api_service.dart';
import 'library_detail_screen.dart';

class LibrarySearchScreen extends ConsumerStatefulWidget {
  const LibrarySearchScreen({super.key});

  @override
  ConsumerState<LibrarySearchScreen> createState() =>
      _LibrarySearchScreenState();
}

class _LibrarySearchScreenState
    extends ConsumerState<LibrarySearchScreen> {
  final _ctrl = TextEditingController();
  List<UserLibrary> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _search(''); // загружаем топ сразу
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final res = await ApiService().searchLibraries(q);
    setState(() {
      _results = res
          .map((e) => UserLibrary.fromJson(e))
          .toList();
      _loading = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text('Найти библиотеку',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Название библиотеки...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
              onSubmitted: _search,
              onChanged: (v) {
                if (v.isEmpty) _search('');
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_searched && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Ничего не найдено',
                  style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant)),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                itemBuilder: (ctx, i) => _LibrarySearchTile(
                  library: _results[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LibraryDetailScreen(libraryId: _results[i].id),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibrarySearchTile extends StatelessWidget {
  final UserLibrary library;
  final VoidCallback onTap;
  const _LibrarySearchTile({required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: cs.primary.withOpacity(0.1),
          child: Icon(Icons.collections_bookmark_outlined, color: cs.primary),
        ),
        title: Text(library.name,
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(library.owner,
            style: GoogleFonts.notoSerif(
                fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('${library.likesCount}',
                style: GoogleFonts.notoSerif(
                    fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
