// lib/screens/recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/recommendations_provider.dart';
import '../providers/library_provider.dart';
import '../models/library.dart';
import '../models/poem.dart';
import '../services/api_service.dart';
import 'poem_detail_screen.dart';
import 'library_detail_screen.dart';

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(recommendationsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_outlined, size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Не удалось загрузить',
                    style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.refresh(recommendationsProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async => ref.refresh(recommendationsProvider),
            child: CustomScrollView(
              slivers: [
                // Заголовок
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'Открытия',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),

                // Стих дня
                if (data.poemOfDay != null)
                  SliverToBoxAdapter(
                    child: _PoemOfDayCard(poem: data.poemOfDay!),
                  ),

                // Топ библиотек
                if (data.topLibraries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Text(
                        'Популярные библиотеки',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.topLibraries.length,
                        itemBuilder: (ctx, i) => _LibraryCard(
                          library: data.topLibraries[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LibraryDetailScreen(
                                  libraryId: data.topLibraries[i].id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Популярные стихи
                if (data.popularPoems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Text(
                        'Часто добавляют',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final poem = data.popularPoems[i];
                        return _PopularPoemTile(
                          poem: poem,
                          onAddToLibrary: () async {
                            final err = await ref
                                .read(myLibraryProvider.notifier)
                                .addPoem(poem.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err ?? 'Добавлено в библиотеку'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        );
                      },
                      childCount: data.popularPoems.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Стих дня ──────────────────────────────────────────────────────────────────

class _PoemOfDayCard extends StatelessWidget {
  final Poem poem;
  const _PoemOfDayCard({required this.poem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        elevation: 0,
        color: cs.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.primary.withOpacity(0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PoemDetailScreen(poem: poem)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Стих дня',
                      style: GoogleFonts.notoSerif(
                          fontSize: 12,
                          color: cs.primary,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  poem.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  poem.author,
                  style: GoogleFonts.notoSerif(
                      fontSize: 13, color: cs.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  poem.text.split('\n').take(3).join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSerif(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Карточка библиотеки (горизонтальный список) ───────────────────────────────

class _LibraryCard extends StatelessWidget {
  final UserLibrary library;
  final VoidCallback onTap;
  const _LibraryCard({required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                color: cs.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              library.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.favorite_outline, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${library.likesCount}',
                    style: GoogleFonts.notoSerif(
                        fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Тайл популярного стиха ────────────────────────────────────────────────────

class _PopularPoemTile extends StatelessWidget {
  final Poem poem;
  final VoidCallback onAddToLibrary;
  const _PopularPoemTile(
      {required this.poem, required this.onAddToLibrary});

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
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(poem.title,
              style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(poem.author,
              style: GoogleFonts.notoSerif(
                  fontSize: 12, color: cs.primary)),
          trailing: IconButton(
            icon: Icon(Icons.add, color: cs.primary),
            onPressed: onAddToLibrary,
            tooltip: 'Добавить в библиотеку',
          ),
        ),
      ),
    );
  }
}
