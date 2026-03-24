import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/poem.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static final DatabaseService _i = DatabaseService._();
  factory DatabaseService() => _i;
  DatabaseService._();

  Database? _db;
  Future<Database> get db async => _db ??= await _init();

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'sscollective.db');
    return openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''CREATE TABLE poems(
      id INTEGER PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL,
      text TEXT NOT NULL, line_count INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE read_poems(
      username TEXT NOT NULL, poem_id INTEGER NOT NULL,
      PRIMARY KEY(username, poem_id))''');
    await db.execute('''CREATE TABLE pinned_poem(
      username TEXT PRIMARY KEY, poem_id INTEGER)''');
    await db.execute('''CREATE TABLE chat_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL,
      role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE sync_queue(
      id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT NOT NULL,
      payload TEXT NOT NULL, created_at INTEGER NOT NULL)''');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('DROP TABLE IF EXISTS read_poems');
      await db.execute('DROP TABLE IF EXISTS pinned_poem');
      await db.execute('''CREATE TABLE read_poems(
        username TEXT NOT NULL, poem_id INTEGER NOT NULL,
        PRIMARY KEY(username, poem_id))''');
      await db.execute('''CREATE TABLE pinned_poem(
        username TEXT PRIMARY KEY, poem_id INTEGER)''');
      await db.execute('DROP TABLE IF EXISTS poems');
      await db.execute('''CREATE TABLE poems(
        id INTEGER PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL,
        text TEXT NOT NULL, line_count INTEGER NOT NULL DEFAULT 0)''');
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
    final rows = await d.query('pinned_poem',
        where: 'username=?', whereArgs: [username]);
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

  // ─── Chat ─────────────────────────────────────────────────────────────────
  Future<List<ChatMessage>> getChatHistory(String username) async {
    final d = await db;
    final rows = await d.query('chat_history',
        where: 'username=?', whereArgs: [username],
        orderBy: 'created_at ASC', limit: 50);
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
  /// Переносит все локальные данные (прочитанные стихи, закреплённое,
  /// историю чата) с [oldUsername] на [newUsername].
  /// Вызывается после успешной смены никнейма на сервере.
  Future<void> migrateUsername(String oldUsername, String newUsername) async {
    final d = await db;

    await d.transaction((txn) async {
      // ── read_poems ────────────────────────────────────────────────────────
      // Удаляем возможные конфликты под новым именем, затем переименовываем
      await txn.delete('read_poems',
          where: 'username=?', whereArgs: [newUsername]);
      await txn.rawUpdate(
        'UPDATE read_poems SET username=? WHERE username=?',
        [newUsername, oldUsername],
      );

      // ── pinned_poem ───────────────────────────────────────────────────────
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

      // ── chat_history ──────────────────────────────────────────────────────
      await txn.rawUpdate(
        'UPDATE chat_history SET username=? WHERE username=?',
        [newUsername, oldUsername],
      );
    });
  }
}
