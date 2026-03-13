import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

final chatProvider = StateNotifierProvider.family<ChatNotifier,
    AsyncValue<List<ChatMessage>>, String>(
  (ref, username) => ChatNotifier(username),
);

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ChatNotifier(this.username) : super(const AsyncValue.loading()) {
    _load();
  }

  final String username;
  final _db = DatabaseService();
  final _api = ApiService();
  bool _sending = false;
  bool get isSending => _sending;

  Future<void> _load() async {
    final history = await _db.getChatHistory(username);
    state = AsyncValue.data(history);
  }

  Future<String?> send(String prompt) async {
    if (!await SyncService().isOnline()) return 'AI-чат требует интернета';

    final userMsg = ChatMessage(
        role: 'user', content: prompt, createdAt: DateTime.now());
    await _db.saveChatMessage(username, userMsg);
    state = AsyncValue.data([...?state.value, userMsg]);
    _sending = true;

    final response = await _api.chatWithAI(prompt);
    _sending = false;

    if (response == null) return 'Ошибка при обращении к AI';
    if (response == '__no_access__')
      return 'Нет доступа к AI. Введите ключ в профиле.';

    final modelMsg = ChatMessage(
        role: 'model', content: response, createdAt: DateTime.now());
    await _db.saveChatMessage(username, modelMsg);
    state = AsyncValue.data([...?state.value, modelMsg]);
    return null;
  }

  Future<void> clear() async {
    await _db.clearChatHistory(username);
    state = const AsyncValue.data([]);
  }
}
