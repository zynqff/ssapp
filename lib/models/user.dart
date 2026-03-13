class User {
  final String username;
  final bool isAdmin;
  final List<String> readPoems;
  final String? pinnedPoemTitle;
  final bool showAllTab;
  final String userData;

  const User({
    required this.username,
    this.isAdmin = false,
    this.readPoems = const [],
    this.pinnedPoemTitle,
    this.showAllTab = false,
    this.userData = '',
  });

  User copyWith({
    List<String>? readPoems,
    String? pinnedPoemTitle,
    bool clearPinned = false,
    bool? showAllTab,
    String? userData,
  }) =>
      User(
        username: username,
        isAdmin: isAdmin,
        readPoems: readPoems ?? this.readPoems,
        pinnedPoemTitle:
            clearPinned ? null : (pinnedPoemTitle ?? this.pinnedPoemTitle),
        showAllTab: showAllTab ?? this.showAllTab,
        userData: userData ?? this.userData,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        username: json['username'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        readPoems: List<String>.from(json['read_poems'] as List? ?? []),
        pinnedPoemTitle: json['pinned_poem_title'] as String?,
        showAllTab: json['show_all_tab'] as bool? ?? false,
        userData: json['user_data'] as String? ?? '',
      );
}
