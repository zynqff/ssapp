import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/poem.dart';
import '../models/chat_message.dart';
import '../models/library.dart';

class DatabaseService {
  static final DatabaseService _i = DatabaseService._();
  factory DatabaseService() => _i;
  DatabaseService._();

  Database? _db;
  Future<Database> get db async => _db ??= await _init();

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'sscollective.db');
    return openDatabase(path, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int v) async {
    await _createV1(db);
    await _createV2(db);
    await _createV3(db);
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS poems(
      id INTEGER PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL,
      text TEXT NOT NULL, line_count INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS chat_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL,
      role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_queue(
      id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT NOT NULL,
      payload TEXT NOT NULL, created_at INTEGER NOT NULL)''');
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS read_poems(
      username TEXT NOT NULL, poem_id INTEGER NOT NULL,
      PRIMARY KEY(username, poem_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS pinned_poem(
      username TEXT PRIMARY KEY, poem_id INTEGER)''');
  }

  // V3: локальный кеш личной библиотеки
  Future<void> _createV3(Database db) async {
    // Метаданные библиотеки
    await db.execute('''CREATE TABLE IF NOT EXISTS local_library(
      username TEXT PRIMARY KEY,
      library_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT "",
      status TEXT NOT NULL DEFAULT "private",
      likes_count INTEGER NOT NULL DEFAULT 0,
      saves_count INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT 0
    )''');

    // Стихи в библиотеке
    await db.execute('''CREATE TABLE IF NOT EXISTS local_library_poems(
      id INTEGER PRIMARY KEY,
      username TEXT NOT NULL,
      library_id INTEGER NOT NULL,
      poem_id INTEGER,
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      text TEXT NOT NULL,
      line_count INTEGER NOT NULL DEFAULT 0,
      is_read INTEGER NOT NULL DEFAULT 0,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      is_custom INTEGER NOT NULL DEFAULT 0,
      added_at INTEGER NOT NULL DEFAULT 0
    )''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lib_poems_username ON local_library_poems(username)');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('DROP TABLE IF EXISTS read_poems');
      await db.execute('DROP TABLE IF EXISTS pinned_poem');
      await db.execute('DROP TABLE IF EXISTS poems');
      await _createV1(db);
      await _createV2(db);
    }
    if (oldV < 3) {
      await _createV3(db);
    }
  }

  // ─── Poems ────────────────────────────────────────────────────────────────
  Future<void> upsertPoems(List<Poem> poems) async {
    final d = await db;
    final b = d.batch();
    for (final p in poems) {
      b.insert('poems', p.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<List<Poem>> getAllPoems() async {
    final d = await db;
    return (await d.query('poems', orderBy: 'title ASC')).map(Poem.fromDb).toList();
  }

  Future<bool> hasPoems() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) as c FROM poems');
    return (r.first['c'] as int) > 0;
  }

  // ─── Read poems ───────────────────────────────────────────────────────────
  Future<List<int>> getReadPoems(String username) async {
    final d = await db;
    final rows = await d.query('read_poems',
        columns: ['poem_id'], where: 'username=?', whereArgs: [username]);
    return rows.map((r) => r['poem_id'] as int).toList();
  }

  Future<void> setReadPoems(String username, List<int> ids) async {
    final d = await db;
    await d.delete('read_poems', where: 'username=?', whereArgs: [username]);
    final b = d.batch();
    for (final id in ids) {
      b.insert('read_poems', {'username': username, 'poem_id': id},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<String> toggleReadPoem(String username, int poemId) async {
    final d = await db;
    final ex = await d.query('read_poems',
        where: 'username=? AND poem_id=?', whereArgs: [username, poemId]);
    if (ex.isNotEmpty) {
      await d.delete('read_poems',
          where: 'username=? AND poem_id=?', whereArgs: [username, poemId]);
      return 'unmarked';
    }
    await d.insert('read_poems', {'username': username, 'poem_id': poemId},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return 'marked';
  }

  // ─── Pinned ───────────────────────────────────────────────────────────────
  Future<int?> getPinnedPoem(String username) async {
    final d = await db;
    final rows =
        await d.query('pinned_poem', where: 'username=?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return rows.first['poem_id'] as int?;
  }

  Future<String> togglePinnedPoem(String username, int poemId) async {
    final d = await db;
    final current = await getPinnedPoem(username);
    if (current == poemId) {
      await d.delete('pinned_poem', where: 'username=?', whereArgs: [username]);
      return 'unpinned';
    }
    await d.insert('pinned_poem', {'username': username, 'poem_id': poemId},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return 'pinned';
  }

  // ─── Local Library ────────────────────────────────────────────────────────

  /// Сохраняет библиотеку полностью (после загрузки с сервера)
  Future<void> saveLibrary(String username, LibraryState state) async {
    final d = await db;
    await d.transaction((txn) async {
      // Метаданные
      await txn.insert(
        'local_library',
        {
          'username': username,
          'library_id': state.library.id,
          'name': state.library.name,
          'description': state.library.description,
          'status': state.library.status,
          'likes_count': state.library.likesCount,
          'saves_count': state.library.savesCount,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Удаляем старые стихи и вставляем новые
      await txn.delete('local_library_poems',
          where: 'username=?', whereArgs: [username]);
      for (final p in state.poems) {
        await txn.insert(
          'local_library_poems',
          {
            'id': p.id,
            'username': username,
            'library_id': p.libraryId,
            'poem_id': p.poemId,
            'title': p.title,
            'author': p.author,
            'text': p.text,
            'line_count': p.lineCount,
            'is_read': p.isRead ? 1 : 0,
            'is_pinned': p.isPinned ? 1 : 0,
            'is_custom': p.isCustom ? 1 : 0,
            'added_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Загружает библиотеку из локального кеша
  Future<LibraryState?> loadLibrary(String username) async {
    final d = await db;
    final libRows = await d.query('local_library',
        where: 'username=?', whereArgs: [username]);
    if (libRows.isEmpty) return null;

    final lib = libRows.first;
    final poemRows = await d.query('local_library_poems',
        where: 'username=?',
        whereArgs: [username],
        orderBy: 'added_at ASC');

    final library = UserLibrary(
      id: lib['library_id'] as int,
      owner: username,
      name: lib['name'] as String,
      description: lib['description'] as String? ?? '',
      status: lib['status'] as String? ?? 'private',
      rejectReason: '',
      likesCount: lib['likes_count'] as int? ?? 0,
      savesCount: lib['saves_count'] as int? ?? 0,
    );

    final poems = poemRows.map((r) => LibraryPoem(
          id: r['id'] as int,
          libraryId: r['library_id'] as int,
          poemId: r['poem_id'] as int?,
          title: r['title'] as String,
          author: r['author'] as String,
          text: r['text'] as String,
          lineCount: r['line_count'] as int,
          isRead: (r['is_read'] as int) == 1,
          isPinned: (r['is_pinned'] as int) == 1,
          isCustom: (r['is_custom'] as int) == 1,
        )).toList();

    return LibraryState(
      library: library,
      poems: poems,
      isLiked: false,
      isSaved: false,
    );
  }

  /// Обновляет is_read для стиха в локальном кеше
  Future<void> toggleLibraryPoemRead(String username, int entryId) async {
    final d = await db;
    final rows = await d.query('local_library_poems',
        where: 'id=? AND username=?', whereArgs: [entryId, username]);
    if (rows.isEmpty) return;
    final current = (rows.first['is_read'] as int) == 1;
    await d.update(
      'local_library_poems',
      {'is_read': current ? 0 : 1},
      where: 'id=? AND username=?',
      whereArgs: [entryId, username],
    );
  }

  /// Обновляет is_pinned для стиха в локальном кеше
  Future<void> setLibraryPoemPinned(
      String username, int entryId, bool isPinned) async {
    final d = await db;
    await d.update(
      'local_library_poems',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id=? AND username=?',
      whereArgs: [entryId, username],
    );
  }

  /// Есть ли локальная библиотека для пользователя
  Future<bool> hasLibrary(String username) async {
    final d = await db;
    final rows = await d.query('local_library',
        where: 'username=?', whereArgs: [username]);
    return rows.isNotEmpty;
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────
  Future<List<ChatMessage>> getChatHistory(String username) async {
    final d = await db;
    final rows = await d.query('chat_history',
        where: 'username=?',
        whereArgs: [username],
        orderBy: 'created_at ASC',
        limit: 50);
    return rows.map(ChatMessage.fromDb).toList();
  }

  Future<void> saveChatMessage(String username, ChatMessage msg) async {
    final d = await db;
    await d.insert('chat_history', {...msg.toDb(), 'username': username});
  }

  Future<void> clearChatHistory(String username) async {
    final d = await db;
    await d.delete('chat_history', where: 'username=?', whereArgs: [username]);
  }

  // ─── Sync queue ───────────────────────────────────────────────────────────
  Future<void> addToSyncQueue(String action, String payload) async {
    final d = await db;
    await d.delete('sync_queue',
        where: 'action=? AND payload=?', whereArgs: [action, payload]);
    await d.insert('sync_queue', {
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async =>
      (await db).query('sync_queue', orderBy: 'created_at ASC');

  Future<void> removeSyncQueueItem(int id) async =>
      (await db).delete('sync_queue', where: 'id=?', whereArgs: [id]);

  // ─── Миграция username ────────────────────────────────────────────────────
  Future<void> migrateUsername(String oldUsername, String newUsername) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('read_poems',
          where: 'username=?', whereArgs: [newUsername]);
      await txn.rawUpdate(
        'UPDATE read_poems SET username=? WHERE username=?',
        [newUsername, oldUsername],
      );

      final pinned = await txn.query('pinned_poem',
          where: 'username=?', whereArgs: [oldUsername]);
      if (pinned.isNotEmpty) {
        final poemId = pinned.first['poem_id'];
        await txn.delete('pinned_poem',
            where: 'username=?', whereArgs: [oldUsername]);
        await txn.delete('pinned_poem',
            where: 'username=?', whereArgs: [newUsername]);
        await txn.insert('pinned_poem',
            {'username': newUsername, 'poem_id': poemId},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await txn.rawUpdate(
        'UPDATE chat_history SET username=? WHERE username=?',
        [newUsername, oldUsername],
      );

      // Мигрируем локальную библиотеку
      // Сначала удаляем возможные конфликтующие записи нового username
      await txn.delete('local_library_poems',
          where: 'username=?', whereArgs: [newUsername]);
      await txn.delete('local_library',
          where: 'username=?', whereArgs: [newUsername]);
      await txn.rawUpdate(
        'UPDATE local_library SET username=? WHERE username=?',
        [newUsername, oldUsername],
      );
      await txn.rawUpdate(
        'UPDATE local_library_poems SET username=? WHERE username=?',
        [newUsername, oldUsername],
      );
    });
  }
}
