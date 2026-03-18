class User {
  final String username;
  final bool isAdmin;
  final List<int> readPoems;
  final int? pinnedPoemId;
  final bool showAllTab;
  final String userData;

  const User({
    required this.username,
    this.isAdmin = false,
    this.readPoems = const [],
    this.pinnedPoemId,
    this.showAllTab = false,
    this.userData = '',
  });

  User copyWith({
    List<int>? readPoems,
    int? pinnedPoemId,
    bool clearPinned = false,
    bool? showAllTab,
    String? userData,
  }) =>
      User(
        username: username,
        isAdmin: isAdmin,
        readPoems: readPoems ?? this.readPoems,
        pinnedPoemId: clearPinned ? null : (pinnedPoemId ?? this.pinnedPoemId),
        showAllTab: showAllTab ?? this.showAllTab,
        userData: userData ?? this.userData,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        username: json['username'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        readPoems: (json['read_poems'] as List? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        pinnedPoemId: (json['pinned_poem_id'] as num?)?.toInt(),
        showAllTab: json['show_all_tab'] as bool? ?? false,
        userData: json['user_data'] as String? ?? '',
      );
}
