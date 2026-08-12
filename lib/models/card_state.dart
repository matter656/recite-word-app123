/// 单词学习阶段。
enum CardStatus {
  newWord('new'),
  learning('learning'),
  reviewing('reviewing'),
  mastered('mastered');

  final String value;
  const CardStatus(this.value);

  static CardStatus fromValue(String v) => CardStatus.values
      .firstWhere((s) => s.value == v, orElse: () => CardStatus.newWord);
}

/// 单词学习状态（每词一条，驱动 SM-2 复习调度）。
class CardState {
  final int id;
  final int wordId;
  final String bookId;
  final CardStatus status;
  final double easeFactor; // SM-2 易度因子，初始 2.5
  final int intervalDays; // 当前复习间隔（天）
  final DateTime dueDate; // 下次复习时间
  final int reviewCount;
  final DateTime? lastReviewedAt;

  const CardState({
    required this.id,
    required this.wordId,
    required this.bookId,
    required this.status,
    required this.easeFactor,
    required this.intervalDays,
    required this.dueDate,
    required this.reviewCount,
    this.lastReviewedAt,
  });

  factory CardState.fromMap(Map<String, dynamic> map) => CardState(
        id: map['id'] as int,
        wordId: map['word_id'] as int,
        bookId: map['book_id'] as String,
        status: CardStatus.fromValue(map['status'] as String),
        easeFactor: (map['ease_factor'] as num).toDouble(),
        intervalDays: map['interval_days'] as int,
        dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
        reviewCount: map['review_count'] as int,
        lastReviewedAt: map['last_reviewed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['last_reviewed_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'word_id': wordId,
        'book_id': bookId,
        'status': status.value,
        'ease_factor': easeFactor,
        'interval_days': intervalDays,
        'due_date': dueDate.millisecondsSinceEpoch,
        'review_count': reviewCount,
        'last_reviewed_at': lastReviewedAt?.millisecondsSinceEpoch,
      };

  CardState copyWith({
    CardStatus? status,
    double? easeFactor,
    int? intervalDays,
    DateTime? dueDate,
    int? reviewCount,
    DateTime? lastReviewedAt,
  }) =>
      CardState(
        id: id,
        wordId: wordId,
        bookId: bookId,
        status: status ?? this.status,
        easeFactor: easeFactor ?? this.easeFactor,
        intervalDays: intervalDays ?? this.intervalDays,
        dueDate: dueDate ?? this.dueDate,
        reviewCount: reviewCount ?? this.reviewCount,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      );
}
