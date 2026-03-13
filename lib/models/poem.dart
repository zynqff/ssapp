class Poem {
  final String title;
  final String author;
  final String text;
  final int lineCount;

  const Poem({
    required this.title,
    required this.author,
    required this.text,
    this.lineCount = 0,
  });

  factory Poem.fromJson(Map<String, dynamic> json) => Poem(
        title: json['title'] as String,
        author: json['author'] as String,
        text: json['text'] as String,
        lineCount: (json['line_count'] as int?) ??
            (json['text'] as String).split('\n').length,
      );

  factory Poem.fromDb(Map<String, dynamic> row) => Poem(
        title: row['title'] as String,
        author: row['author'] as String,
        text: row['text'] as String,
        lineCount: row['line_count'] as int,
      );

  Map<String, dynamic> toDb() => {
        'title': title,
        'author': author,
        'text': text,
        'line_count': lineCount,
      };

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'text': text,
        'line_count': lineCount,
      };

  Poem copyWith({String? title, String? author, String? text}) => Poem(
        title: title ?? this.title,
        author: author ?? this.author,
        text: text ?? this.text,
        lineCount: lineCount,
      );
}
