// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poems_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchQueryHash() => r'7025e359cd02f38f6320640581424352d023d8dc';

/// See also [searchQuery].
@ProviderFor(searchQuery)
final searchQueryProvider = AutoDisposeProvider<String>.internal(
  searchQuery,
  name: r'searchQueryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$searchQueryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SearchQueryRef = AutoDisposeProviderRef<String>;
String _$filteredPoemsHash() => r'b413871c8da5c2c8e44befd3247563313771ef8a';

/// See also [filteredPoems].
@ProviderFor(filteredPoems)
final filteredPoemsProvider = AutoDisposeProvider<List<Poem>>.internal(
  filteredPoems,
  name: r'filteredPoemsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredPoemsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FilteredPoemsRef = AutoDisposeProviderRef<List<Poem>>;
String _$poemsHash() => r'85224c2ebb92344ba5f1b9e836a7c7cdb63b06f1';

/// See also [Poems].
@ProviderFor(Poems)
final poemsProvider =
    AutoDisposeAsyncNotifierProvider<Poems, List<Poem>>.internal(
  Poems.new,
  name: r'poemsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$poemsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Poems = AutoDisposeAsyncNotifier<List<Poem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
