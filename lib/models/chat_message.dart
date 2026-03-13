class ChatMessage {
  final String role; // 'user' | 'model'
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromDb(Map<String, dynamic> row) => ChatMessage(
        role: row['role'] as String,
        content: row['content'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );

  Map<String, dynamic> toDb() => {
        'role': role,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
