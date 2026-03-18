class Poem {
  final int id;
  final String title;
  final String author;
  final String text;
  final int lineCount;

  const Poem({
    required this.id,
    required this.title,
    required this.author,
    required this.text,
    this.lineCount = 0,
  });

  factory Poem.fromJson(Map<String, dynamic> json) => Poem(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        author: json['author'] as String,
        text: json['text'] as String,
        lineCount: (json['line_count'] as int?) ??
            (json['text'] as String).split('\n').length,
      );

  factory Poem.fromDb(Map<String, dynamic> row) => Poem(
        id: row['id'] as int,
        title: row['title'] as String,
        author: row['author'] as String,
        text: row['text'] as String,
        lineCount: row['line_count'] as int,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'title': title,
        'author': author,
        'text': text,
        'line_count': lineCount,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'text': text,
        'line_count': lineCount,
      };

  Poem copyWith({String? title, String? author, String? text}) => Poem(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        text: text ?? this.text,
        lineCount: lineCount,
      );
}
