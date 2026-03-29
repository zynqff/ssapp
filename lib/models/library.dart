// lib/models/library.dart

class UserLibrary {
  final int id;
  final String owner;
  final String name;
  final String description;
  final String status; // pending | published | rejected
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
  });

  factory LibraryPoem.fromJson(Map<String, dynamic> j) => LibraryPoem(
        id: (j['id'] as num).toInt(),
        libraryId: (j['library_id'] as num).toInt(),
        poemId: (j['poem_id'] as num?)?.toInt(),
        title: j['title'] as String? ?? '',
        author: j['author'] as String? ?? '',
        text: j['text'] as String? ?? '',
        lineCount: (j['line_count'] as num?)?.toInt() ?? 0,
        isRead: j['is_read'] as bool? ?? false,
        isCustom: j['is_custom'] as bool? ?? false,
      );

  LibraryPoem copyWith({bool? isRead}) => LibraryPoem(
        id: id,
        libraryId: libraryId,
        poemId: poemId,
        title: title,
        author: author,
        text: text,
        lineCount: lineCount,
        isRead: isRead ?? this.isRead,
        isCustom: isCustom,
      );
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
    UserLibrary? library,
    List<LibraryPoem>? poems,
    bool? isLiked,
    bool? isSaved,
  }) =>
      LibraryState(
        library: library ?? this.library,
        poems: poems ?? this.poems,
        isLiked: isLiked ?? this.isLiked,
        isSaved: isSaved ?? this.isSaved,
      );
}
