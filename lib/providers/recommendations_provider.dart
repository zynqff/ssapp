import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/poem.dart';
import '../models/library.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

part 'recommendations_provider.g.dart';

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

@riverpod
class Recommendations extends _$Recommendations {
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<RecommendationsState> build() => _load();

  Future<RecommendationsState> _load() async {
    try {
      final data = await _api.fetchRecommendations();
      if (data == null) return const RecommendationsState();

      Poem? poemOfDay;
      if (data['poem_of_day'] != null) {
        poemOfDay = Poem.fromJson(data['poem_of_day'] as Map<String, dynamic>);
      }
      final topLibraries = (data['top_libraries'] as List? ?? [])
          .map((e) => UserLibrary.fromJson(e as Map<String, dynamic>))
          .toList();
      final popularPoems = (data['popular_poems'] as List? ?? [])
          .map((e) => Poem.fromJson(e as Map<String, dynamic>))
          .toList();

      return RecommendationsState(
        poemOfDay: poemOfDay,
        topLibraries: topLibraries,
        popularPoems: popularPoems,
      );
    } catch (e) {
      debugPrint('[Recommendations] Ошибка загрузки: $e');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

// final recommendationsProvider = recommendationsProvider$;
