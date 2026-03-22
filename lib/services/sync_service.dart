import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import 'api_service.dart';
import '../models/poem.dart';

enum SyncResult { success, offline, error }

class SyncService {
  static final SyncService _i = SyncService._();
  factory SyncService() => _i;
  SyncService._();

  final _db = DatabaseService();
  final _supabase = Supabase.instance.client;

  Future<bool> isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  // Стихи теперь грузим напрямую из Supabase
  Future<SyncResult> syncPoems() async {
    if (!await isOnline()) return SyncResult.offline;
    try {
      final rows = await _supabase
          .from('poem')
          .select('id, title, author, text');
      final poems = (rows as List)
          .map((r) => Poem.fromJson(r as Map<String, dynamic>))
          .toList();
      await _db.upsertPoems(poems);
      return SyncResult.success;
    } catch (_) {
      return SyncResult.error;
    }
  }

  // Очередь оффлайн-действий — toggle_read/pin теперь идут в Supabase напрямую
  Future<void> flushQueue(String username) async {
    if (!await isOnline()) return;
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    for (final item in await _db.getSyncQueue()) {
      final id = item['id'] as int;
      final action = item['action'] as String;
      final payload =
          jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      bool ok = false;

      try {
        switch (action) {
          case 'toggle_read':
            // Читаем текущий список и применяем изменение
            final data = await _supabase
                .from('user')
                .select('read_poems_json')
                .eq('supabase_uid', uid)
                .single();
            final reads = ((data['read_poems_json'] as List?) ?? [])
                .map((e) => (e as num).toInt())
                .toList();
            final poemId = (payload['poem_id'] as num).toInt();
            if (reads.contains(poemId)) {
              reads.remove(poemId);
            } else {
              reads.add(poemId);
            }
            await _supabase
                .from('user')
                .update({'read_poems_json': reads})
                .eq('supabase_uid', uid);
            ok = true;

          case 'toggle_pin':
            final data = await _supabase
                .from('user')
                .select('pinned_poem_id')
                .eq('supabase_uid', uid)
                .single();
            final poemId = (payload['poem_id'] as num).toInt();
            final current = (data['pinned_poem_id'] as num?)?.toInt();
            final newPinned = current == poemId ? null : poemId;
            await _supabase
                .from('user')
                .update({'pinned_poem_id': newPinned})
                .eq('supabase_uid', uid);
            ok = true;

          case 'update_profile':
            final updates = <String, dynamic>{};
            if (payload['user_data'] != null) {
              updates['user_data'] = payload['user_data'];
            }
            if (payload['show_all_tab'] != null) {
              updates['show_all_tab'] = payload['show_all_tab'];
            }
            if (updates.isNotEmpty) {
              await _supabase
                  .from('user')
                  .update(updates)
                  .eq('supabase_uid', uid);
            }
            ok = true;
        }
      } catch (_) {}

      if (ok) await _db.removeSyncQueueItem(id);
    }
  }

  Future<SyncResult> fullSync(String username) async {
    if (!await isOnline()) return SyncResult.offline;
    await flushQueue(username);
    return syncPoems();
  }
}
