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
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''CREATE TABLE poems(
      title TEXT PRIMARY KEY, author TEXT NOT NULL,
      text TEXT NOT NULL, line_count INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE read_poems(
      username TEXT NOT NULL, poem_title TEXT NOT NULL,
      PRIMARY KEY(username, poem_title))''');
    await db.execute('''CREATE TABLE pinned_poem(
      username TEXT PRIMARY KEY, poem_title TEXT)''');
    await db.execute('''CREATE TABLE chat_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL,
      role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE sync_queue(
      id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT NOT NULL,
      payload TEXT NOT NULL, created_at INTEGER NOT NULL)''');
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
  Future<List<String>> getReadPoems(String username) async {
    final d = await db;
    final rows = await d.query('read_poems',
        columns: ['poem_title'], where: 'username=?', whereArgs: [username]);
    return rows.map((r) => r['poem_title'] as String).toList();
  }

  Future<void> setReadPoems(String username, List<String> titles) async {
    final d = await db;
    await d.delete('read_poems', where: 'username=?', whereArgs: [username]);
    final b = d.batch();
    for (final t in titles) {
      b.insert('read_poems', {'username': username, 'poem_title': t},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<String> toggleReadPoem(String username, String title) async {
    final d = await db;
    final ex = await d.query('read_poems',
        where: 'username=? AND poem_title=?', whereArgs: [username, title]);
    if (ex.isNotEmpty) {
      await d.delete('read_poems',
          where: 'username=? AND poem_title=?', whereArgs: [username, title]);
      return 'unmarked';
    }
    await d.insert('read_poems', {'username': username, 'poem_title': title},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return 'marked';
  }

  // ─── Pinned ───────────────────────────────────────────────────────────────
  Future<String?> getPinnedPoem(String username) async {
    final d = await db;
    final rows = await d.query('pinned_poem',
        where: 'username=?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return rows.first['poem_title'] as String?;
  }

  Future<String> togglePinnedPoem(String username, String title) async {
    final d = await db;
    final current = await getPinnedPoem(username);
    if (current == title) {
      await d.delete('pinned_poem', where: 'username=?', whereArgs: [username]);
      return 'unpinned';
    }
    await d.insert('pinned_poem', {'username': username, 'poem_title': title},
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
    await d.insert('sync_queue', {
      'action': action, 'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async =>
      (await db).query('sync_queue', orderBy: 'created_at ASC');

  Future<void> removeSyncQueueItem(int id) async =>
      (await db).delete('sync_queue', where: 'id=?', whereArgs: [id]);
}
