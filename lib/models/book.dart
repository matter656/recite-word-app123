/// 词书模型。
class Book {
  final String id; // 词书标识，如 cet4 / cet6 / ky / ielts
  final String name; // 展示名，如「四级核心词汇」
  final String description;
  final int wordCount;

  const Book({
    required this.id,
    required this.name,
    required this.description,
    required this.wordCount,
  });

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        wordCount: map['word_count'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'word_count': wordCount,
      };
}
