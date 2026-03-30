// lib/models/library.dart

class UserLibrary {
  final int id;
  final String owner;
  final String name;
  final String description;
  final String status;
  final String rejectReason;
  final int likesCount;
  final int savesCount;

  const UserLibrary({
    required this.id,
    required this.owner,
    required this.name,
    required this.description,
    required this.status,
    required this.rejectReason,
    required this.likesCount,
    required this.savesCount,
  });

  factory UserLibrary.fromJson(Map<String, dynamic> j) => UserLibrary(
        id: (j['id'] as num).toInt(),
        owner: j['owner'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        rejectReason: j['reject_reason'] as String? ?? '',
        likesCount: (j['likes_count'] as num?)?.toInt() ?? 0,
        savesCount: (j['saves_count'] as num?)?.toInt() ?? 0,
      );

  bool get isPublished => status == 'published';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
}

class LibraryPoem {
  final int id;
  final int libraryId;
  final int? poemId;
  final String title;
  final String author;
  final String text;
  final int lineCount;
  final bool isRead;
  final bool isCustom;
  final bool isPinned;

  const LibraryPoem({
    required this.id,
    required this.libraryId,
    this.poemId,
    required this.title,
    required this.author,
    required this.text,
    required this.lineCount,
    required this.isRead,
    required this.isCustom,
    this.isPinned = false,
  });

  factory LibraryPoem.fromJson(Map<String, dynamic> j) {
    final text = j['text'] as String? ?? '';
    final rawCount = (j['line_count'] as num?)?.toInt() ?? 0;
    return LibraryPoem(
      id: (j['id'] as num).toInt(),
      libraryId: (j['library_id'] as num).toInt(),
      poemId: (j['poem_id'] as num?)?.toInt(),
      title: j['title'] as String? ?? '',
      author: j['author'] as String? ?? '',
      text: text,
      lineCount: rawCount > 0
          ? rawCount
          : text.trim().isEmpty ? 0 : text.trim().split('\n').length,
      isRead: j['is_read'] as bool? ?? false,
      isCustom: j['is_custom'] as bool? ?? false,
      isPinned: j['is_pinned'] as bool? ?? false,
    );
  }

  LibraryPoem copyWith({bool? isRead, bool? isPinned}) => LibraryPoem(
        id: id, libraryId: libraryId, poemId: poemId,
        title: title, author: author, text: text, lineCount: lineCount,
        isRead: isRead ?? this.isRead, isCustom: isCustom,
        isPinned: isPinned ?? this.isPinned,
      );

  String get preview {
    final lines = text.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines[0];
    return '${lines[0]}\n${lines[1]}';
  }
}

class LibraryState {
  final UserLibrary library;
  final List<LibraryPoem> poems;
  final bool isLiked;
  final bool isSaved;

  const LibraryState({
    required this.library,
    required this.poems,
    required this.isLiked,
    required this.isSaved,
  });

  factory LibraryState.fromJson(Map<String, dynamic> j) => LibraryState(
        library: UserLibrary.fromJson(j['library'] as Map<String, dynamic>),
        poems: (j['poems'] as List? ?? [])
            .map((e) => LibraryPoem.fromJson(e as Map<String, dynamic>))
            .toList(),
        isLiked: j['is_liked'] as bool? ?? false,
        isSaved: j['is_saved'] as bool? ?? false,
      );

  LibraryState copyWith({
    UserLibrary? library, List<LibraryPoem>? poems,
    bool? isLiked, bool? isSaved,
  }) => LibraryState(
        library: library ?? this.library, poems: poems ?? this.poems,
        isLiked: isLiked ?? this.isLiked, isSaved: isSaved ?? this.isSaved,
      );
}

enum SortDir { asc, desc }
enum LibrarySortBy { added, title, author, length, read, unread }

extension LibrarySortByLabel on LibrarySortBy {
  String get label {
    switch (this) {
      case LibrarySortBy.added:  return 'По добавлению';
      case LibrarySortBy.title:  return 'По названию';
      case LibrarySortBy.author: return 'По автору';
      case LibrarySortBy.length: return 'По длине';
      case LibrarySortBy.read:   return 'Прочитанные';
      case LibrarySortBy.unread: return 'Непрочитанные';
    }
  }
}
