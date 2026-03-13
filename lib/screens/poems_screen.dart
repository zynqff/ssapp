import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/poems_provider.dart';
import '../providers/auth_provider.dart';
import '../models/poem.dart';
import '../widgets/poem_card.dart';
import 'poem_detail_screen.dart';
import 'profile_screen.dart';
import 'ai_chat_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Поиск...', border: InputBorder.none),
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
              )
            : const Text('Сборник стихов'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchCtrl.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              }
            },
          ),
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.smart_toy_outlined),
              tooltip: 'AI чат',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiChatScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
        bottom: isLoggedIn
            ? TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Все'),
                  Tab(text: 'Непрочитанные'),
                  Tab(text: 'Прочитанные'),
                ],
              )
            : null,
      ),
      body: poemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _EmptyState(
          icon: Icons.wifi_off,
          message: e.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.read(poemsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ),
        data: (_) => isLoggedIn
            ? TabBarView(
                controller: _tabs,
                children: [
                  _List(poems: filtered, user: user),
                  _List(
                      poems: filtered
                          .where((p) => !user.readPoems.contains(p.title))
                          .toList(),
                      user: user),
                  _List(
                      poems: filtered
                          .where((p) => user.readPoems.contains(p.title))
                          .toList(),
                      user: user),
                ],
              )
            : _List(poems: filtered, user: null),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  final List<Poem> poems;
  final dynamic user;
  const _List({required this.poems, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (poems.isEmpty) {
      return const _EmptyState(icon: Icons.search_off, message: 'Ничего не найдено');
    }
    return AnimationLimiter(
      child: RefreshIndicator(
        onRefresh: () => ref.read(poemsProvider.notifier).refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: poems.length,
          itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
            position: i,
            duration: const Duration(milliseconds: 350),
            child: SlideAnimation(
              verticalOffset: 40,
              child: FadeInAnimation(
                child: PoemCard(
                  poem: poems[i],
                  isRead: user?.readPoems.contains(poems[i].title) ?? false,
                  isPinned: user?.pinnedPoemTitle == poems[i].title,
                  onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) =>
                              PoemDetailScreen(poem: poems[i]))),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}
