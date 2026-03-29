// lib/providers/recommendations_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poem.dart';
import '../models/library.dart';
import '../services/api_service.dart';

class RecommendationsState {
  final Poem? poemOfDay;
  final List<UserLibrary> topLibraries;
  final List<Poem> popularPoems;

  const RecommendationsState({
    this.poemOfDay,
    this.topLibraries = const [],
    this.popularPoems = const [],
  });
}

final recommendationsProvider = StateNotifierProvider<RecommendationsNotifier,
    AsyncValue<RecommendationsState>>((ref) {
  return RecommendationsNotifier();
});

class RecommendationsNotifier
    extends StateNotifier<AsyncValue<RecommendationsState>> {
  RecommendationsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  final _api = ApiService();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.fetchRecommendations();
      if (data == null) {
        state = const AsyncValue.data(RecommendationsState());
        return;
      }

      Poem? poemOfDay;
      if (data['poem_of_day'] != null) {
        poemOfDay =
            Poem.fromJson(data['poem_of_day'] as Map<String, dynamic>);
      }

      final topLibraries = (data['top_libraries'] as List? ?? [])
          .map((e) => UserLibrary.fromJson(e as Map<String, dynamic>))
          .toList();

      final popularPoems = (data['popular_poems'] as List? ?? [])
          .map((e) => Poem.fromJson(e as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(RecommendationsState(
        poemOfDay: poemOfDay,
        topLibraries: topLibraries,
        popularPoems: popularPoems,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
