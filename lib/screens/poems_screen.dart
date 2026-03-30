import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/poems_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/config_provider.dart';
import '../models/poem.dart';
import '../widgets/poem_card.dart';
import 'poem_detail_screen.dart';

class PoemsScreen extends ConsumerStatefulWidget {
  const PoemsScreen({super.key});
  @override
  ConsumerState<PoemsScreen> createState() => _PoemsScreenState();
}

class _PoemsScreenState extends ConsumerState<PoemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  int _selectedTab = 0;
  bool _bannerShown = false;
  bool? _lastShowAllTab;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index != _selectedTab) {
        setState(() => _selectedTab = _tabs.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowBanner());
  }

  void _syncTabs(bool showAll) {
    if (_lastShowAllTab == showAll) return;
    _lastShowAllTab = showAll;
    final tabCount = showAll ? 3 : 2;
    final newIndex = _selectedTab.clamp(0, tabCount - 1);
    _tabs.dispose();
    _tabs = TabController(length: tabCount, vsync: this, initialIndex: newIndex)
      ..addListener(() {
        if (_tabs.index != _selectedTab) {
          setState(() => _selectedTab = _tabs.index);
        }
      });
    _selectedTab = newIndex;
  }

  void _maybeShowBanner() {
    if (_bannerShown) return;
    final config = ref.read(configProvider).valueOrNull;
    if (config == null || config.bannerText.isEmpty) return;
    _bannerShown = true;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _showBannerDialog(config.bannerText, config.bannerColor);
    });
  }

  void _showBannerDialog(String text, String colorKey) {
    final cs = Theme.of(context).colorScheme;
    final bannerColor = switch (colorKey) {
      'error'   => cs.error,
      'warning' => const Color(0xFFE6A817),
      _         => cs.primary,
    };
    final icon = switch (colorKey) {
      'error'   => Icons.error_outline_rounded,
      'warning' => Icons.warning_amber_rounded,
      _         => Icons.info_outline_rounded,
    };

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: bannerColor.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: BoxDecoration(
                  color: bannerColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: bannerColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: bannerColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      switch (colorKey) {
                        'error'   => 'Важное уведомление',
                        'warning' => 'Внимание',
                        _         => 'Информация',
                      },
                      style: GoogleFonts.playfairDisplay(
                        color: bannerColor, fontSize: 17, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceVariant,
                      fixedSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Text(text,
                    style: GoogleFonts.notoSerif(
                        color: cs.onSurface, fontSize: 14.5, height: 1.6)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: bannerColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Понятно',
                        style: GoogleFonts.notoSerif(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final poemsAsync = ref.watch(poemsProvider);
    final filtered = ref.watch(filteredPoemsProvider);
    final isLoggedIn = user != null;
    final accent = ref.watch(themeNotifierProvider).accent;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    final config = ref.watch(configProvider).valueOrNull;
    if (config != null && config.bannerText.isNotEmpty && !_bannerShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowBanner());
    }

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _showSearch
                                ? TextField(
                                    key: const ValueKey('search'),
                                    controller: _searchCtrl,
                                    autofocus: true,
                                    style: GoogleFonts.playfairDisplay(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 22,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Поиск...',
                                      hintStyle: GoogleFonts.playfairDisplay(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 22,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (v) =>
                                        ref.read(searchQueryProvider.notifier).state = v,
                                  )
                                : Align(
                                    key: const ValueKey('title'),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Сборник стихов',
                                      style: GoogleFonts.playfairDisplay(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderIcon(
                          icon: _showSearch
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          onTap: () {
                            setState(() => _showSearch = !_showSearch);
                            if (!_showSearch) {
                              _searchCtrl.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            }
                          },
                        ),
                      ],
                    ),
                    if (isLoggedIn) ...[
                      const SizedBox(height: 14),
                      _PillTabs(
                        labels: user!.showAllTab
                            ? const ['Все', 'Непрочитанные', 'Прочитанные']
                            : const ['Непрочитанные', 'Прочитанные'],
                        selected: _selectedTab,
                        accent: accent,
                        onSelect: (i) {
                          _tabs.animateTo(i);
                          setState(() => _selectedTab = i);
                        },
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: poemsAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: accent)),
              error: (e, _) => _EmptyState(
                icon: Icons.wifi_off_rounded,
                message: e.toString(),
                action: FilledButton.icon(
                  onPressed: () => ref.read(poemsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ),
              data: (_) {
                if (!isLoggedIn) return _PoemList(poems: filtered, user: null);
                _syncTabs(user!.showAllTab);
                final unread = filtered
                    .where((p) => !user.readPoems.contains(p.id))
                    .toList();
                final readList = filtered
                    .where((p) => user.readPoems.contains(p.id))
                    .toList();
                return TabBarView(
                  controller: _tabs,
                  children: user.showAllTab
                      ? [
                          _PoemList(poems: filtered, user: user),
                          _PoemList(poems: unread, user: user),
                          _PoemList(poems: readList, user: user),
                        ]
                      : [
                          _PoemList(poems: unread, user: user),
                          _PoemList(poems: readList, user: user),
                        ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline, width: 0.8),
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final Color accent;
  final ValueChanged<int> onSelect;
  const _PillTabs({
    required this.labels,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: active ? accent.withOpacity(0.18) : cs.surfaceVariant,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: active ? accent.withOpacity(0.6) : cs.outline,
                  width: active ? 1.2 : 0.8,
                ),
              ),
              child: Text(
                labels[i],
                style: GoogleFonts.notoSerif(
                  color: active ? accent : cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PoemList extends ConsumerWidget {
  final List<Poem> poems;
  final dynamic user;
  const _PoemList({required this.poems, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (poems.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        message: 'Ничего не найдено',
      );
    }
    final accent = ref.watch(themeNotifierProvider).accent;
    return AnimationLimiter(
      child: RefreshIndicator(
        color: accent,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        onRefresh: () => ref.read(poemsProvider.notifier).refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: poems.length,
          itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
            position: i,
            duration: const Duration(milliseconds: 320),
            child: SlideAnimation(
              verticalOffset: 36,
              child: FadeInAnimation(
                child: PoemCard(
                  poem: poems[i],
                  isRead: user?.readPoems.contains(poems[i].id) ?? false,
                  isPinned: user?.pinnedPoemId == poems[i].id,
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => PoemDetailScreen(poem: poems[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const _EmptyState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: cs.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                  color: cs.onSurfaceVariant, fontSize: 14)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}
