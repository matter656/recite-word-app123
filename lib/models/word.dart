/// 单词模型（词库词条）。
class Word {
  final int id;
  final String bookId;
  final String word;
  final String phonetic;
  final String meaning;
  final String? exampleEn; // 英文例句，可能为空
  final String? exampleCn; // 例句中文翻译

  const Word({
    required this.id,
    required this.bookId,
    required this.word,
    required this.phonetic,
    required this.meaning,
    this.exampleEn,
    this.exampleCn,
  });

  factory Word.fromMap(Map<String, dynamic> map) => Word(
        id: map['id'] as int,
        bookId: map['book_id'] as String,
        word: map['word'] as String,
        phonetic: map['phonetic'] as String,
        meaning: map['meaning'] as String,
        exampleEn: map['example_en'] as String?,
        exampleCn: map['example_cn'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'word': word,
        'phonetic': phonetic,
        'meaning': meaning,
        'example_en': exampleEn,
        'example_cn': exampleCn,
      };
}
